#!/bin/bash

# omybuntu:summary=Build the Omybuntu Live ISO from the clean Ubuntu Base Rootfs
# omybuntu:requires-sudo=true

set -e

# -------------------------------------------------------------------
# Cache system: layers + invalidation by checksums of source files
#   --no-cache, --clean : force full rebuild, delete all caches
# -------------------------------------------------------------------

WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD_DIR="$WORKSPACE/build"
CHROOT_DIR="$BUILD_DIR/chroot"
IMAGE_DIR="$BUILD_DIR/image"
ISO_OUT="$WORKSPACE/omybuntu.iso"

CACHE_DIR="$WORKSPACE/.iso-cache"
CACHE_MANIFEST="$CACHE_DIR/manifest.sh"
BASE_CACHE_FILE="$CACHE_DIR/base-chroot.tar.gz"
UBUNTU_VERSION="26.04"
UBUNTU_CODENAME="resolute"
ROOTFS_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-amd64.tar.gz"
tail_pid=""

cleanup_mounts() {
  for mount in "$CHROOT_DIR/sys" "$CHROOT_DIR/proc" "$CHROOT_DIR/dev/pts" "$CHROOT_DIR/dev"; do
    if mountpoint -q "$mount"; then
      sudo umount -lf "$mount" 2>/dev/null || true
    fi
  done
}

write_live_apt_pins() {
  sudo mkdir -p "$CHROOT_DIR/etc/apt/preferences.d"
  cat <<EOF | sudo tee "$CHROOT_DIR/etc/apt/preferences.d/99-omybuntu-live-desktop" > /dev/null
# Omybuntu uses Hyprland via SDDM; GNOME session managers and downstream
# SDDM themes should not be pulled in as package recommendations.
Package: gdm3
Pin: release *
Pin-Priority: -1

Package: gnome-session
Pin: release *
Pin-Priority: -1

Package: ubuntu-session
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop-minimal
Pin: release *
Pin-Priority: -1

Package: budgie-sddm-theme
Pin: release *
Pin-Priority: -1

Package: sddm-theme-breeze
Pin: release *
Pin-Priority: -1
EOF
}

cleanup() {
  if [[ -n ${tail_pid:-} ]]; then
    kill "$tail_pid" 2>/dev/null || true
    wait "$tail_pid" 2>/dev/null || true
    tail_pid=""
  fi

  if [[ -f "$CHROOT_DIR/etc/sudoers.d/chroot-root" ]]; then
    sudo rm -f "$CHROOT_DIR/etc/sudoers.d/chroot-root" 2>/dev/null || true
  fi

  cleanup_mounts
}

trap cleanup EXIT

## --- Parse arguments --------------------------------------------------------
CLEAN_BUILD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cache|--clean) CLEAN_BUILD=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if $CLEAN_BUILD; then
  echo "Clean build requested -- deleting build directory..."
  sudo rm -rf "$BUILD_DIR"
fi

INITIALIZED=false
if [[ -d "$CHROOT_DIR/etc" ]]; then
  INITIALIZED=true
fi

# --- Pre-build cleanup & extraction -----------------------------------------

for tool in wget tar mksquashfs xorriso grub-mkrescue mformat rsync magick; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: Required host tool '$tool' is not installed." >&2
    echo "       Install missing tools with: sudo apt install imagemagick mtools xorriso grub-pc-bin grub-efi-amd64-bin squashfs-tools" >&2
    exit 1
  fi
done

# Unmount anything still mounted from a previous run
cleanup_mounts

if ! $INITIALIZED; then
  echo "Building Omybuntu Live ISO from Ubuntu Base rootfs..."
  sudo rm -rf "$BUILD_DIR"
  sudo mkdir -p "$BUILD_DIR" "$CHROOT_DIR" "$IMAGE_DIR/casper"

  # 1. Download Ubuntu Base Rootfs
  if [[ ! -f "$WORKSPACE/ubuntu-base.tar.gz" ]]; then
    echo "Downloading Ubuntu Base rootfs..."
    wget -O "$WORKSPACE/ubuntu-base.tar.gz" "$ROOTFS_URL"
  fi

  # 2. Extract Rootfs (creates /dev, /proc, /sys mount points)
  echo "Extracting rootfs..."
  sudo tar -xzf "$WORKSPACE/ubuntu-base.tar.gz" -C "$CHROOT_DIR"
  sudo mkdir -p "$CHROOT_DIR/dev/pts" "$CHROOT_DIR/proc" "$CHROOT_DIR/sys"
else
  echo "Reusing existing chroot directory at $CHROOT_DIR..."
  sudo rm -rf "$IMAGE_DIR"
  sudo mkdir -p "$IMAGE_DIR/casper"
fi

# --- Virtual filesystems & basic chroot setup (always) ----------------------

echo "Mounting virtual filesystems..."
# Mount only if not already mounted
mountpoint -q "$CHROOT_DIR/dev" || sudo mount --bind /dev "$CHROOT_DIR/dev"
mountpoint -q "$CHROOT_DIR/dev/pts" || sudo mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mountpoint -q "$CHROOT_DIR/proc" || sudo mount -t proc proc "$CHROOT_DIR/proc"
mountpoint -q "$CHROOT_DIR/sys" || sudo mount -t sysfs sysfs "$CHROOT_DIR/sys"
sudo cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"
write_live_apt_pins

# ---------------------------------------------------------------------------
# INITIAL SETUP: APT + SYSTEM UTILITIES (only when not already initialized)
# ---------------------------------------------------------------------------

if ! $INITIALIZED; then
  # 5. Setup APT Sources inside Chroot
  echo "Configuring APT sources..."
  cat <<EOF | sudo tee "$CHROOT_DIR/etc/apt/sources.list" > /dev/null
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

  # 6. Run System Installations inside Chroot
  echo "Installing kernel, systemd, boot, and live utilities inside chroot..."

  sudo chroot "$CHROOT_DIR" env DEBIAN_FRONTEND=noninteractive bash -c "
    apt-get update -qq && apt-get install -y -qq curl gpg ca-certificates
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' \
      > /etc/apt/sources.list.d/charm.list
  "

  sudo chroot "$CHROOT_DIR" env DEBIAN_FRONTEND=noninteractive apt-get update
  sudo chroot "$CHROOT_DIR" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    linux-image-generic \
    systemd \
    systemd-sysv \
    network-manager \
    dbus \
    casper \
    plymouth \
    grub-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64 \
    binutils \
    git \
    curl \
    sudo \
    wget \
    rsync \
    gdisk \
    btrfs-progs \
    cryptsetup \
    debootstrap \
    dosfstools \
    software-properties-common \
    build-essential \
    pkg-config \
    libssl-dev \
    gum \
    mtools \
    parted \
    lvm2
fi

# ---------------------------------------------------------------------------
# COMMON STEPS (run regardless of initialization state)
# ---------------------------------------------------------------------------

# 7. Copy Omybuntu to Chroot (rsync avoids self-copy of build/ into itself)
echo "Syncing Omybuntu codebase into chroot..."
sudo mkdir -p "$CHROOT_DIR/opt/omybuntu"
sudo rsync -a \
  --delete \
  --exclude='build/' \
  --exclude='.git/' \
  --exclude='ubuntu-base.tar.gz' \
  --exclude='*.iso' \
  --exclude='installer/target/' \
  --exclude='.iso-cache/' \
  "$WORKSPACE/" \
  "$CHROOT_DIR/opt/omybuntu/"

build_branch=$(git -C "$WORKSPACE" branch --show-current 2>/dev/null || echo "unknown")
build_commit=$(git -C "$WORKSPACE" rev-parse --short HEAD 2>/dev/null || echo "unknown")
build_describe=$(git -C "$WORKSPACE" describe --tags --always --dirty 2>/dev/null || cat "$WORKSPACE/version")
build_channel="$build_branch"
if [[ $build_branch == "main" || $build_branch == "master" ]]; then
  build_channel="stable"
elif [[ $build_branch == "rc" ]]; then
  build_channel="rc"
elif [[ $build_branch == "dev" ]]; then
  build_channel="dev"
elif [[ -z $build_branch ]]; then
  build_branch="unknown"
  build_channel="unknown"
fi

cat <<EOF | sudo tee "$CHROOT_DIR/opt/omybuntu/.build-info" >/dev/null
OMYBUNTU_BUILD_BRANCH=$build_branch
OMYBUNTU_BUILD_CHANNEL=$build_channel
OMYBUNTU_BUILD_COMMIT=$build_commit
OMYBUNTU_BUILD_DESCRIBE=$build_describe
EOF

sudo mkdir -p "$CHROOT_DIR/root/.local/share"
sudo ln -snf /opt/omybuntu "$CHROOT_DIR/root/.local/share/omybuntu"

# Clean up potentially broken legacy APT hooks in persistent chroot
sudo rm -f "$CHROOT_DIR/etc/apt/apt.conf.d/99walker-restart"

# 7a. Compile the Ratatui TUI installer inside the chroot
echo "Installing Rust toolchain and compiling TUI installer..."
sudo chroot "$CHROOT_DIR" /bin/bash -c "
  set -e
  export HOME=/root
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable --no-modify-path --quiet
  export PATH=\"/root/.cargo/bin:\$PATH\"
  cd /opt/omybuntu/installer
  cargo build --release --jobs \$(nproc)
  cp target/release/omybuntu-installer /usr/local/bin/omybuntu-installer
  cp target/release/omybuntu-tui-monitors /usr/local/bin/omybuntu-tui-monitors
  chmod +x /usr/local/bin/omybuntu-installer /usr/local/bin/omybuntu-tui-monitors
  rm -rf /root/.cargo /root/.rustup
  rm -rf /opt/omybuntu/installer/target
"

# 7b. Run Omybuntu setup inside the chroot
echo "Running Omybuntu setup inside chroot..."
# Start tailing the install log from the host so progress is visible
sudo touch "$CHROOT_DIR/var/log/omybuntu-install.log"
sudo tail -f "$CHROOT_DIR/var/log/omybuntu-install.log" 2>/dev/null &
tail_pid=$!
# Give tail a moment to start before the chroot overwrites the log
sleep 0.5

# Allow root to use sudo without a terminal inside the chroot.
# Many install scripts use sudo even when running as root; without this,
# sudo fails silently in the headless chroot environment (no tty).
echo "root ALL=(ALL) NOPASSWD: ALL" | sudo tee "$CHROOT_DIR/etc/sudoers.d/chroot-root" >/dev/null
sudo chmod 0440 "$CHROOT_DIR/etc/sudoers.d/chroot-root"

sudo chroot "$CHROOT_DIR" /usr/bin/env -i \
  HOME=/root \
  USER=root \
  LOGNAME=root \
  SHELL=/bin/bash \
  TERM=linux \
  PATH=/opt/omybuntu/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  OMYBUNTU_PATH=/opt/omybuntu \
  OMYBUNTU_INSTALL=/opt/omybuntu/install \
  OMYBUNTU_INSTALL_LOG_FILE=/var/log/omybuntu-install.log \
  OMYBUNTU_ONLINE_INSTALL=true \
  OMYBUNTU_ISO_BUILD=true \
  OMYBUNTU_CHROOT_INSTALL=true \
  OMYBUNTU_ISO_HOST_PROGRESS=true \
  OMYBUNTU_LIVE_USER=omybuntu \
  OMYBUNTU_TARGET_USER=omybuntu \
  /bin/bash -e -c "
    cd /opt/omybuntu
    ./install.sh
    ./install/iso/setup-iso.sh
  "

# Clean up the temporary sudoers override
sudo rm -f "$CHROOT_DIR/etc/sudoers.d/chroot-root"

kill "$tail_pid" 2>/dev/null || true
wait "$tail_pid" 2>/dev/null || true
tail_pid=""

# ---------------------------------------------------------------------------
# ISO PACKAGING (always runs)
# ---------------------------------------------------------------------------

# 8. Unmount Virtual Filesystems
echo "Unmounting virtual filesystems..."
cleanup_mounts

# 9. Prepare Boot/Casper directory structure for ISO
echo "Preparing boot structure..."
KERNEL_IMG=$(find "$CHROOT_DIR/boot" -name "vmlinuz-*" -type f | head -n1)
INITRD_IMG=$(find "$CHROOT_DIR/boot" -name "initrd.img-*" -type f | head -n1)

sudo cp "$KERNEL_IMG" "$IMAGE_DIR/casper/vmlinuz"
sudo cp "$INITRD_IMG" "$IMAGE_DIR/casper/initrd"

sudo mkdir -p "$IMAGE_DIR/.disk"
echo "Omybuntu Resolute Live ISO" | sudo tee "$IMAGE_DIR/.disk/info" > /dev/null

sudo mkdir -p "$IMAGE_DIR/boot/grub"
sudo cp "$WORKSPACE/install/iso/grub.cfg" "$IMAGE_DIR/boot/grub/grub.cfg"

# Generate GRUB theme assets for the ISO boot menu (always English on live ISO)
echo "Generating GRUB theme for ISO boot menu..."
export OMYBUNTU_PATH="$WORKSPACE"
export OMYBUNTU_ISO_BUILD=true
export OMYBUNTU_LANGUAGE=en
export GRUB_THEME_OUT_DIR="$IMAGE_DIR/boot/grub/themes/omybuntu"
source "$WORKSPACE/install/packaging/grub-theme.sh"

# 10. Compress chroot into SquashFS
echo "Creating filesystem.squashfs (this may take a few minutes)..."

sudo chroot "$CHROOT_DIR" dpkg-query -W --showformat='${Package} ${Version}\n' | \
  sudo tee "$IMAGE_DIR/casper/filesystem.manifest" > /dev/null
sudo du -sx --block-size=1 "$CHROOT_DIR" | cut -f1 | \
  sudo tee "$IMAGE_DIR/casper/filesystem.size" > /dev/null

sudo rm -rf "$CHROOT_DIR"/var/cache/apt/archives/*.deb

sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/casper/filesystem.squashfs" \
  -comp xz -e opt/omybuntu/build

echo "Generating ISO checksum manifest..."
sudo bash -c 'cd "$1" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt' bash "$IMAGE_DIR"
sudo chmod 0644 "$IMAGE_DIR/md5sum.txt"

# 11. Build bootable ISO with grub-mkrescue
echo "Building the bootable ISO..."
sudo grub-mkrescue -o "$ISO_OUT" "$IMAGE_DIR"

echo "ISO successfully built at: $ISO_OUT"

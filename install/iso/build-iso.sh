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

for tool in wget tar mksquashfs xorriso grub-mkrescue mformat rsync; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: Required host tool '$tool' is not installed." >&2
    echo "       Install missing tools with: sudo apt install mtools xorriso grub-pc-bin grub-efi-amd64-bin squashfs-tools" >&2
    exit 1
  fi
done

# Unmount anything still mounted from a previous run
sudo umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true

if ! $INITIALIZED; then
  echo "Building Omybuntu Live ISO from Ubuntu Base rootfs..."
  sudo rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR" "$CHROOT_DIR" "$IMAGE_DIR/casper"

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
  mkdir -p "$IMAGE_DIR/casper"
fi

# --- Virtual filesystems & basic chroot setup (always) ----------------------

echo "Mounting virtual filesystems..."
# Mount only if not already mounted
mountpoint -q "$CHROOT_DIR/dev" || sudo mount --bind /dev "$CHROOT_DIR/dev"
mountpoint -q "$CHROOT_DIR/dev/pts" || sudo mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mountpoint -q "$CHROOT_DIR/proc" || sudo mount -t proc proc "$CHROOT_DIR/proc"
mountpoint -q "$CHROOT_DIR/sys" || sudo mount -t sysfs sysfs "$CHROOT_DIR/sys"
sudo cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

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
    live-boot \
    live-boot-initramfs-tools \
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
    mtools
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
  chmod +x /usr/local/bin/omybuntu-installer
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

sudo chroot "$CHROOT_DIR" env \
  OMYBUNTU_ONLINE_INSTALL=true \
  OMYBUNTU_ISO_BUILD=true \
  OMYBUNTU_CHROOT_INSTALL=true \
  OMYBUNTU_ISO_HOST_PROGRESS=true \
  /bin/bash -c "
    cd /opt/omybuntu
    ./install.sh
    ./install/iso/setup-iso.sh
  "

kill "$tail_pid" 2>/dev/null || true
wait "$tail_pid" 2>/dev/null || true

# ---------------------------------------------------------------------------
# ISO PACKAGING (always runs)
# ---------------------------------------------------------------------------

# 8. Unmount Virtual Filesystems
echo "Unmounting virtual filesystems..."
sudo umount -lf "$CHROOT_DIR/sys"
sudo umount -lf "$CHROOT_DIR/proc"
sudo umount -lf "$CHROOT_DIR/dev/pts"
sudo umount -lf "$CHROOT_DIR/dev"

# 9. Prepare Boot/Casper directory structure for ISO
echo "Preparing boot structure..."
KERNEL_IMG=$(find "$CHROOT_DIR/boot" -name "vmlinuz-*" -type f | head -n1)
INITRD_IMG=$(find "$CHROOT_DIR/boot" -name "initrd.img-*" -type f | head -n1)

sudo cp "$KERNEL_IMG" "$IMAGE_DIR/casper/vmlinuz"
sudo cp "$INITRD_IMG" "$IMAGE_DIR/casper/initrd"

sudo mkdir -p "$IMAGE_DIR/boot/grub"
sudo cp "$WORKSPACE/install/iso/grub.cfg" "$IMAGE_DIR/boot/grub/grub.cfg"

# Generate GRUB theme assets for the ISO boot menu
# This uses the host system's magick to create the theme in IMAGE_DIR
echo "Generating GRUB theme for ISO boot menu..."
THEME_DIR="$IMAGE_DIR/boot/grub/themes/omybuntu"
mkdir -p "$THEME_DIR"

# Solid Omybuntu dark brown background with subtle vignette
magick -size 1920x1080 \
  -define gradient:center=50%,50% \
  radial-gradient:'#2a1a10'-'#140a05' \
  "$THEME_DIR/background.png"

# Select indicators (subtle rounded amber rectangles at 15% opacity)
for w in 200 400 600; do
  magick -size ${w}x28 xc:none \
  -channel RGBA \
  -fill 'rgba(245,158,11,0.15)' \
  -draw "roundrectangle 4,2 $((w-4)),26 14,14" \
  "$THEME_DIR/select_${w}.png"
done

# Scrollbar thumb (semi-transparent rounded bar at 60% opacity)
magick -size 6x30 xc:none \
  -channel RGBA \
  -fill 'rgba(92,64,51,0.6)' \
  -draw "roundrectangle 0,0 6,30 3,3" \
  "$THEME_DIR/scrollbar_thumb.png"

# Copy theme.txt and font
cp "$WORKSPACE/default/grub/theme.txt" "$THEME_DIR/theme.txt"
cp /usr/share/grub/unicode.pf2 "$THEME_DIR/unicode.pf2" 2>/dev/null || true

# 10. Compress chroot into SquashFS
echo "Creating filesystem.squashfs (this may take a few minutes)..."

sudo chroot "$CHROOT_DIR" dpkg-query -W --showformat='${Package} ${Version}\n' | \
  sudo tee "$IMAGE_DIR/casper/filesystem.manifest" > /dev/null
sudo du -sx --block-size=1 "$CHROOT_DIR" | cut -f1 | \
  sudo tee "$IMAGE_DIR/casper/filesystem.size" > /dev/null

sudo rm -rf "$CHROOT_DIR"/var/cache/apt/archives/*.deb

sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/casper/filesystem.squashfs" \
  -comp xz -e opt/omybuntu/build

# 11. Build bootable ISO with grub-mkrescue
echo "Building the bootable ISO..."
sudo grub-mkrescue -o "$ISO_OUT" "$IMAGE_DIR"

echo "ISO successfully built at: $ISO_OUT"

#!/bin/bash

# omybuntu:summary=Build the Omybuntu Live ISO from the clean Ubuntu Base Rootfs
# omybuntu:requires-sudo=true

set -e

# Define directories
WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD_DIR="$WORKSPACE/build"
CHROOT_DIR="$BUILD_DIR/chroot"
IMAGE_DIR="$BUILD_DIR/image"
ISO_OUT="$WORKSPACE/omybuntu.iso"

UBUNTU_VERSION="24.04"
ROOTFS_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-amd64.tar.gz"

echo "Building Omybuntu Live ISO from Ubuntu Base rootfs..."

# Check required tools on host
for tool in wget tar mksquashfs xorriso grub-mkrescue; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: Required host tool '$tool' is not installed." >&2
    exit 1
  fi
done

# Clean up previous builds
sudo umount -lf "$CHROOT_DIR/sys" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/proc" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/dev/pts" 2>/dev/null || true
sudo umount -lf "$CHROOT_DIR/dev" 2>/dev/null || true
sudo rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR" "$CHROOT_DIR" "$IMAGE_DIR/casper"

# 1. Download Ubuntu Base Rootfs
if [[ ! -f "$WORKSPACE/ubuntu-base.tar.gz" ]]; then
  echo "Downloading Ubuntu Base rootfs..."
  wget -O "$WORKSPACE/ubuntu-base.tar.gz" "$ROOTFS_URL"
fi

# 2. Extract Rootfs
echo "Extracting rootfs..."
sudo tar -xzf "$WORKSPACE/ubuntu-base.tar.gz" -C "$CHROOT_DIR"

# 3. Mount Virtual Filesystems
echo "Mounting virtual filesystems..."
sudo mount --bind /dev "$CHROOT_DIR/dev"
sudo mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
sudo mount -t proc proc "$CHROOT_DIR/proc"
sudo mount -t sysfs sysfs "$CHROOT_DIR/sys"

# 4. Copy DNS Resolv for Internet Access in chroot
sudo cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

# 5. Setup APT Sources inside Chroot
echo "Configuring APT sources..."
cat <<EOF | sudo tee "$CHROOT_DIR/etc/apt/sources.list" >/dev/null
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOF

# 6. Run System Installations inside Chroot
echo "Installing kernel, systemd, boot, and live utilities inside chroot..."

# Add Charm repo (provides gum)
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
  dosfstools \
  gum

# 7. Copy Omybuntu to Chroot and Run Installations
echo "Copying Omybuntu codebase and running installation..."
sudo mkdir -p "$CHROOT_DIR/opt/omybuntu"
sudo cp -r "$WORKSPACE/"* "$CHROOT_DIR/opt/omybuntu/"

# Execute the setups
sudo chroot "$CHROOT_DIR" env OMYBUNTU_ONLINE_INSTALL=true OMYBUNTU_ISO_BUILD=true /bin/bash -c "
  cd /opt/omybuntu
  ./install/iso/setup-iso.sh
  ./install.sh
"

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

# Copy custom grub.cfg
sudo mkdir -p "$IMAGE_DIR/boot/grub"
sudo cp "$WORKSPACE/install/iso/grub.cfg" "$IMAGE_DIR/boot/grub/grub.cfg"

# 10. Compress chroot into SquashFS
echo "Creating filesystem.squashfs (this may take a few minutes)..."
sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/casper/filesystem.squashfs" -comp xz -e opt/omybuntu/build

# 11. Build bootable ISO with grub-mkrescue
echo "Building the bootable ISO..."
sudo grub-mkrescue -o "$ISO_OUT" "$IMAGE_DIR"

echo "ISO successfully built at: $ISO_OUT"

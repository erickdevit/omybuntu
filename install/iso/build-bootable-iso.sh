#!/bin/bash

set -euo pipefail

IMAGE_DIR=${1:?Image directory is required}
CHROOT_DIR=${2:?Chroot directory is required}
ISO_OUT=${3:?ISO output path is required}

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

EFI_TREE="$WORK_DIR/efi"
EFI_IMAGE="$WORK_DIR/efi.img"
BIOS_CORE="$WORK_DIR/core.img"
BIOS_CONFIG="$WORK_DIR/grub-bios.cfg"
BIOS_IMAGE="$IMAGE_DIR/boot/grub/i386-pc/eltorito.img"

mkdir -p "$EFI_TREE/EFI/BOOT" "$(dirname "$BIOS_IMAGE")" "$IMAGE_DIR/EFI/BOOT"

SHIM="$CHROOT_DIR/usr/lib/shim/shimx64.efi.signed.latest"
MOK_MANAGER="$CHROOT_DIR/usr/lib/shim/mmx64.efi"
SIGNED_GRUB="$CHROOT_DIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"

for file in "$SHIM" "$MOK_MANAGER" "$SIGNED_GRUB"; do
  if [[ ! -f $file ]]; then
    echo "Missing signed Secure Boot artifact: $file" >&2
    exit 1
  fi
  sbverify --list "$file" >/dev/null
done

sbverify --list "$IMAGE_DIR/casper/vmlinuz" >/dev/null

cp "$SHIM" "$EFI_TREE/EFI/BOOT/BOOTX64.EFI"
cp "$SIGNED_GRUB" "$EFI_TREE/EFI/BOOT/grubx64.efi"
cp "$MOK_MANAGER" "$EFI_TREE/EFI/BOOT/mmx64.efi"

cat > "$EFI_TREE/EFI/BOOT/grub.cfg" <<'EOF'
search --no-floppy --file --set=omybuntu_iso /boot/grub/grub.cfg
set root=$omybuntu_iso
configfile /boot/grub/grub.cfg
EOF

cp -a "$EFI_TREE/EFI/BOOT/." "$IMAGE_DIR/EFI/BOOT/"

dd if=/dev/zero of="$EFI_IMAGE" bs=1M count=16 status=none
mkfs.vfat -F 12 -n OMYBUNTU "$EFI_IMAGE" >/dev/null
mcopy -s -i "$EFI_IMAGE" "$EFI_TREE/EFI" ::/

cp -a /usr/lib/grub/i386-pc/. "$IMAGE_DIR/boot/grub/i386-pc/"
cat > "$BIOS_CONFIG" <<'EOF'
search --no-floppy --file --set=omybuntu_iso /boot/grub/grub.cfg
set root=$omybuntu_iso
set prefix=($root)/boot/grub
configfile /boot/grub/grub.cfg
EOF

grub-mkstandalone \
  --format=i386-pc \
  --output="$BIOS_CORE" \
  --install-modules="normal iso9660 biosdisk search search_fs_file configfile" \
  --modules="normal iso9660 biosdisk search search_fs_file configfile" \
  --locales="" \
  --fonts="" \
  "boot/grub/grub.cfg=$BIOS_CONFIG"

cat /usr/lib/grub/i386-pc/cdboot.img "$BIOS_CORE" > "$BIOS_IMAGE"

xorriso -as mkisofs \
  -R -J -joliet-long -l -iso-level 3 \
  -V OMYBUNTU \
  --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 0xef "$EFI_IMAGE" \
  -appended_part_as_gpt \
  -c boot/grub/boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e --interval:appended_partition_2:all:: \
  -no-emul-boot \
  -o "$ISO_OUT" \
  "$IMAGE_DIR"

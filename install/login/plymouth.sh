theme_dir="/usr/share/plymouth/themes/omybuntu"
staging_dir=$(mktemp -d)
trap 'rm -rf "$staging_dir"' EXIT

accent_hex=f59e0b

find "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/default/plymouth" -maxdepth 1 -type f -exec cp -t "$staging_dir/" {} +
omybuntu-cmd-generate-ascii-logo "$staging_dir/logo.png" "$accent_hex"
omybuntu-cmd-recolor-image-assets "$staging_dir" "$accent_hex" \
  bullet.png entry.png lock.png progress_bar.png progress_box.png

sudo mkdir -p "$theme_dir"
sudo cp -a "$staging_dir/." "$theme_dir/"

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme omybuntu
else
  sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/omybuntu/omybuntu.plymouth 150
  sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/omybuntu/omybuntu.plymouth
fi

# Rebuild initrd so the custom theme is actually embedded at boot
sudo update-initramfs -u

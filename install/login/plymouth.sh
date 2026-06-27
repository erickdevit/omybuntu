if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo cp -r "$OMYBUNTU_PATH/default/plymouth" /usr/share/plymouth/themes/omybuntu/
  sudo plymouth-set-default-theme omybuntu
  # Rebuild initrd so the custom theme is actually embedded at boot
  sudo update-initramfs -u
fi

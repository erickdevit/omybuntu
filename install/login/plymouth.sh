sudo cp -r "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/default/plymouth" /usr/share/plymouth/themes/omybuntu/

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme omybuntu
else
  sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/omybuntu/omybuntu.plymouth 150
  sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/omybuntu/omybuntu.plymouth
fi

# Rebuild initrd so the custom theme is actually embedded at boot
sudo update-initramfs -u

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if [[ $(plymouth-set-default-theme) != "omybuntu" ]]; then
    sudo cp -r "$OMYBUNTU_PATH/default/plymouth" /usr/share/plymouth/themes/omybuntu/
    sudo plymouth-set-default-theme omybuntu
  fi
fi

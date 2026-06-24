echo "Fix display backlight on supported ASUS Panther Lake laptops"

EXPERTBOOK_DROP_IN="/etc/limine-entry-tool.d/asus-expertbook-b9406-display.conf"

if omybuntu-hw-asus-expertbook-b9406 || omybuntu-hw-asus-zenbook-ux5406aa; then
  if [[ -f $EXPERTBOOK_DROP_IN ]]; then
    sudo sed -i '/xe\.enable_dpcd_backlight/d' "$EXPERTBOOK_DROP_IN"
  fi

  source "$OMYBUNTU_PATH/install/config/hardware/asus/fix-asus-ptl-display-backlight.sh"

  if omybuntu-cmd-present limine-update; then
    sudo limine-update
  fi
fi

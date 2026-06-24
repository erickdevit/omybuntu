echo "Allow updating of timezone by right-clicking on the clock (or running omybuntu-cmd-tzupdate)"

if omybuntu-cmd-missing tzupdate; then
  bash "$OMYBUNTU_PATH/install/config/timezones.sh"
  omybuntu-refresh-waybar
fi

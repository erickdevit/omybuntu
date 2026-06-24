echo "Update Waybar screen recording command"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && grep -q 'omybuntu-cmd-screenrecord' "$WAYBAR_CONFIG"; then
  sed -i 's/omybuntu-cmd-screenrecord/omybuntu-capture-screenrecording/g' "$WAYBAR_CONFIG"
  omybuntu-restart-waybar
fi

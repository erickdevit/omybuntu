echo "Rename screen recording command"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && grep -q 'omybuntu-capture-screencording' "$WAYBAR_CONFIG"; then
  sed -i 's/omybuntu-capture-screencording/omybuntu-capture-screenrecording/g' "$WAYBAR_CONFIG"
  omybuntu-restart-waybar
fi

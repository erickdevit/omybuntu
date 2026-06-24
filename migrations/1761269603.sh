echo "Add right-click terminal action to waybar omybuntu menu icon"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && ! grep -A5 '"custom/omybuntu"' "$WAYBAR_CONFIG" | grep -q '"on-click-right"'; then
  sed -i '/"on-click": "omybuntu-menu",/a\    "on-click-right": "omybuntu-launch-terminal",' "$WAYBAR_CONFIG"
fi

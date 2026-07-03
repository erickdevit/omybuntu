echo "Update vertical waybar clock format-alt to vertical layout to prevent horizontal expansion on click"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f "$WAYBAR_CONFIG" ]]; then
  sed -i '/"clock#vertical": {/,/"on-click-right"/ s/"format-alt": "[^"]*"/"format-alt": "{:L%d\\n%b\\n%y}"/' "$WAYBAR_CONFIG"
fi

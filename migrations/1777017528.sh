echo "Show battery status notification on right-click of the waybar battery icon"

if ! grep -q 'omybuntu-battery-status' ~/.config/waybar/config.jsonc; then
  sed -i '/"on-click": "omybuntu-menu power",/a\    "on-click-right": "notify-send -u low \\"$(omybuntu-battery-status)\\"",' ~/.config/waybar/config.jsonc
  omybuntu-restart-waybar
fi

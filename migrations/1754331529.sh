echo "Update Waybar for new Omybuntu menu"

if ! grep -q "" ~/.config/waybar/config.jsonc; then
  omybuntu-refresh-waybar
fi

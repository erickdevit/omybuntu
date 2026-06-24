echo "Replace bluetooth GUI with TUI"

omybuntu-pkg-add bluetui
omybuntu-pkg-drop blueberry

if ! grep -q "omybuntu-launch-bluetooth" ~/.config/waybar/config.jsonc; then
  sed -i 's/blueberry/omybuntu-launch-bluetooth/' ~/.config/waybar/config.jsonc
fi

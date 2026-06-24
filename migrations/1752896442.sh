echo "Replace volume control GUI with a TUI"

if omybuntu-cmd-missing wiremix; then
  omybuntu-pkg-add wiremix
  omybuntu-pkg-drop pavucontrol
  omybuntu-refresh-applications
  omybuntu-refresh-waybar
fi

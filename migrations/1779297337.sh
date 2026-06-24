echo "Enable Voxtype keybindings toggle for existing installs"

if omybuntu-cmd-present voxtype; then
  omybuntu-hyprland-toggle voxtype on
fi

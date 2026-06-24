echo "Switch lmstudio -> lmstudio-bin"

if pacman -Q lmstudio &>/dev/null; then
  omybuntu-pkg-drop lmstudio
  omybuntu-pkg-add lmstudio-bin
fi

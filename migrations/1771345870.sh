echo "Switch lmstudio -> lmstudio-bin"

if omybuntu-pkg-present lmstudio &>/dev/null; then
  omybuntu-pkg-drop lmstudio
  omybuntu-pkg-add lmstudio-bin
fi

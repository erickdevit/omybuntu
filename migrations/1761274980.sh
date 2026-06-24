echo "Migrate to proper packages for localsend and asdcontrol"

if omybuntu-pkg-present localsend-bin; then
  omybuntu-pkg-drop localsend-bin
  omybuntu-pkg-add localsend
fi

if omybuntu-pkg-present asdcontrol-git; then
  omybuntu-pkg-drop asdcontrol-git
  omybuntu-pkg-add asdcontrol
fi

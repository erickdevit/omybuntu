echo "Replace wofi with walker as the default launcher"

if omybuntu-cmd-missing walker; then
  omybuntu-pkg-add walker-bin libqalculate

  omybuntu-pkg-drop wofi
  rm -rf ~/.config/wofi

  mkdir -p ~/.config/walker
  cp -r ~/.local/share/omybuntu/config/walker/* ~/.config/walker/
fi

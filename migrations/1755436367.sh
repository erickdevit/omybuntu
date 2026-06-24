echo "Add minimal starship prompt to terminal"

if omybuntu-cmd-missing starship; then
  omybuntu-pkg-add starship
  cp $OMYBUNTU_PATH/config/starship.toml ~/.config/starship.toml
fi

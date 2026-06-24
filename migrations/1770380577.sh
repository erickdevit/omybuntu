echo "Use interactive background selector menu"

mkdir -p ~/.config/elephant/menus
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_background_selector.lua ~/.config/elephant/menus/omybuntu_background_selector.lua
omybuntu-restart-walker

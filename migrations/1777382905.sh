echo "Use interactive unlock (Plymouth) selector menu"

mkdir -p ~/.config/elephant/menus
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_unlocks.lua ~/.config/elephant/menus/omybuntu_unlocks.lua
omybuntu-restart-walker

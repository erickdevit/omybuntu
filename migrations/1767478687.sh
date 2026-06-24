echo "Add opencode with system theming"

omybuntu-pkg-add opencode

# Add config using omybuntu theme by default
if [[ ! -f ~/.config/opencode/opencode.json ]]; then
  mkdir -p ~/.config/opencode
  cp $OMYBUNTU_PATH/config/opencode/opencode.json ~/.config/opencode/opencode.json
fi

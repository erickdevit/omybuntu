# Omybuntu logo in a font for Waybar use
mkdir -p ~/.local/share/fonts
cp "$OMYBUNTU_PATH/config/omybuntu.ttf" ~/.local/share/fonts/
fc-cache

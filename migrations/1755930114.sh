echo "Add new Omybuntu Menu icon to Waybar"

mkdir -p ~/.local/share/fonts
cp ~/.local/share/omybuntu/config/omybuntu.ttf ~/.local/share/fonts/
fc-cache

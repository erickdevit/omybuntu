echo "Update fastfetch config with new Omybuntu logo"

omybuntu-refresh-config fastfetch/config.jsonc

mkdir -p ~/.config/omybuntu/branding
cp $OMYBUNTU_PATH/icon.txt ~/.config/omybuntu/branding/about.txt

# Copy over Omybuntu configs
mkdir -p ~/.config
cp -R "$OMYBUNTU_PATH"/config/* ~/.config/
mkdir -p ~/.config/omybuntu/branding

# Use default bashrc from Omybuntu
cp "$OMYBUNTU_PATH"/default/bashrc ~/.bashrc

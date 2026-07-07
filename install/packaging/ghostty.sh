echo "Installing Ghostty terminal..."

# Add Ghostty PPA and install
sudo add-apt-repository -y ppa:apandada1/ghostty
sudo apt-get update -qq
sudo apt-get install -y ghostty

# Copy default Ghostty config
mkdir -p ~/.config/ghostty
cp -Rpf "$OMYBUNTU_PATH/config/ghostty/." ~/.config/ghostty/

# Set Ghostty as the default terminal via xdg-terminals.list
mkdir -p ~/.config
cat > ~/.config/xdg-terminals.list <<EOF
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
com.mitchellh.ghostty.desktop
EOF

echo "Ghostty installed and set as default terminal."

FONT_DIR="/usr/local/share/fonts/truetype/omybuntu"
mkdir -p "$FONT_DIR"

# Omybuntu logo in a font for Waybar use
cp "$OMYBUNTU_PATH/config/omybuntu.ttf" "$FONT_DIR/"

# JetBrainsMono Nerd Font — the default monospace used across the entire
# desktop (terminals, waybar, swayosd, hyprlock, sddm, fontconfig)
if ! fc-list | grep -qi "JetBrainsMono.*Nerd" 2>/dev/null; then
  echo "Installing JetBrainsMono Nerd Font..."
  curl -fsSL -o /tmp/JetBrainsMono.tar.xz \
    'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz'
  tar -xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR/"
  rm -f /tmp/JetBrainsMono.tar.xz
fi

fc-cache -f

echo "Configure Ghostty custom slanted cursor and trail shader"

mkdir -p ~/.config/ghostty/shaders
cp -pf "$OMYBUNTU_PATH/config/ghostty/shaders/cursor_tail.glsl" ~/.config/ghostty/shaders/cursor_tail.glsl

if [[ -f ~/.config/ghostty/config ]]; then
  sed -i '/custom-shader/d' ~/.config/ghostty/config
  sed -i '/cursor-opacity/d' ~/.config/ghostty/config
  
  cat << 'EOF' >> ~/.config/ghostty/config
cursor-opacity = 0
custom-shader = "~/.config/ghostty/shaders/cursor_tail.glsl"
custom-shader-animation = always
EOF
fi

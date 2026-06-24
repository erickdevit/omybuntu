echo "Add sample post-boot hook"

mkdir -p ~/.config/omybuntu/hooks/post-boot.d

if [[ ! -f ~/.config/omybuntu/hooks/post-boot.d/weather.sample ]]; then
  cp "$OMYBUNTU_PATH/config/omybuntu/hooks/post-boot.d/weather.sample" ~/.config/omybuntu/hooks/post-boot.d/weather.sample
fi

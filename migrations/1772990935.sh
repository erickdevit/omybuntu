echo "Add sample low battery notification hook"

mkdir -p ~/.config/omybuntu/hooks/battery-low.d

if [[ ! -f ~/.config/omybuntu/hooks/battery-low.d/play-warning-sound.sample ]]; then
  cp "$OMYBUNTU_PATH/config/omybuntu/hooks/battery-low.d/play-warning-sound.sample" ~/.config/omybuntu/hooks/battery-low.d/play-warning-sound.sample
fi

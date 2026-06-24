echo "Make hackerman available as new theme"

if [[ ! -L ~/.config/omybuntu/themes/hackerman ]]; then
  rm -rf ~/.config/omybuntu/themes/hackerman
  ln -nfs ~/.local/share/omybuntu/themes/hackerman ~/.config/omybuntu/themes/
fi

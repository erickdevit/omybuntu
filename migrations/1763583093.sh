echo "Make ethereal available as new theme"

if [[ ! -L ~/.config/omybuntu/themes/ethereal ]]; then
  rm -rf ~/.config/omybuntu/themes/ethereal
  ln -nfs ~/.local/share/omybuntu/themes/ethereal ~/.config/omybuntu/themes/
fi

echo "Add the new ristretto theme as an option"

if [[ ! -L ~/.config/omybuntu/themes/ristretto ]]; then
  ln -nfs ~/.local/share/omybuntu/themes/ristretto ~/.config/omybuntu/themes/
fi

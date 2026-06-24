echo "Add the new Flexoki Light theme"

if [[ ! -L ~/.config/omybuntu/themes/flexoki-light ]]; then
  ln -nfs ~/.local/share/omybuntu/themes/flexoki-light ~/.config/omybuntu/themes/
fi

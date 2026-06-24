echo "Add new matte black theme"

if [[ ! -L $HOME/.config/omybuntu/themes/matte-black ]]; then
  ln -snf ~/.local/share/omybuntu/themes/matte-black ~/.config/omybuntu/themes/
fi

echo "Add Catppuccin Latte light theme"

if [[ ! -L $HOME/.config/omybuntu/themes/catppuccin-latte ]]; then
  ln -snf ~/.local/share/omybuntu/themes/catppuccin-latte ~/.config/omybuntu/themes/
fi

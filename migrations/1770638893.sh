echo "Add Tmux as an option with themed styling"

omybuntu-pkg-add tmux

if [[ ! -f ~/.config/tmux/tmux.conf ]]; then
  mkdir -p ~/.config/tmux
  cp $OMYBUNTU_PATH/config/tmux/tmux.conf ~/.config/tmux/tmux.conf
  omybuntu-theme-refresh
fi

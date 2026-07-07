echo "Remove Foot from the default install and hide launcher clutter from Walker"

if [[ -f $OMYBUNTU_PATH/install/config/hide-launcher-clutter.sh ]]; then
  bash "$OMYBUNTU_PATH/install/config/hide-launcher-clutter.sh"
fi

if omybuntu-cmd-present omybuntu-refresh-applications; then
  omybuntu-refresh-applications
fi

if [[ -f ~/.config/xdg-terminals.list ]]; then
  if grep -q '^foot\.desktop$' ~/.config/xdg-terminals.list; then
    cat > ~/.config/xdg-terminals.list <<EOF
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
com.mitchellh.ghostty.desktop
EOF
  fi
fi
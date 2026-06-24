stop_install_log

echo_in_style() {
  echo -e "\033[1;36m$1\033[0m"
}

clear
echo
cat "$OMYBUNTU_PATH"/logo.txt 2>/dev/null || true
echo

# Display installation time if available
if [[ -f $OMYBUNTU_INSTALL_LOG_FILE ]] && grep -q "Total:" "$OMYBUNTU_INSTALL_LOG_FILE" 2>/dev/null; then
  echo
  TOTAL_TIME=$(tail -n 20 "$OMYBUNTU_INSTALL_LOG_FILE" | grep "^Total:" | sed 's/^Total:[[:space:]]*//')
  if [[ -n $TOTAL_TIME ]]; then
    echo_in_style "Installed in $TOTAL_TIME"
  fi
else
  echo_in_style "Finished installing"
fi

if sudo test -f /etc/sudoers.d/99-omybuntu-installer; then
  sudo rm -f /etc/sudoers.d/99-omybuntu-installer &>/dev/null
fi

# Exit gracefully if user chooses not to reboot
if gum confirm --padding "0 0 0 $((PADDING_LEFT + 32))" --show-help=false --default --affirmative "Reboot Now" --negative "" ""; then
  # Clear screen to hide any shutdown messages
  clear

  if [[ -n ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
    touch /var/tmp/omybuntu-install-completed
    exit 0
  else
    sudo reboot 2>/dev/null
  fi
fi

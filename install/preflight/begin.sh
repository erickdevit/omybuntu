clear_logo
if [[ -n ${OMYBUNTU_ISO_BUILD:-} || -n ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
  echo "Installing..."
else
  gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing..."
fi
echo
start_install_log

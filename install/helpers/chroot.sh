# Starting the installer with OMYBUNTU_CHROOT_INSTALL=1 will put it into chroot mode
chrootable_systemctl_enable() {
  if [[ -n ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
    sudo systemctl enable $1 || true
  else
    sudo systemctl enable --now $1 || true
  fi
}

# Export the function so it's available in subshells
export -f chrootable_systemctl_enable

if sudo test -f /etc/sudoers.d/99-omybuntu-installer-reboot; then
  sudo rm -f /etc/sudoers.d/99-omybuntu-installer-reboot
fi

if sudo test -f /etc/sudoers.d/99-omybuntu-live-installer; then
  sudo rm -f /etc/sudoers.d/99-omybuntu-live-installer
fi

echo "Use verbose package lists for pacman"

if [[ -f /etc/pacman.conf ]]; then
  sudo sed -i '/^ILoveCandy$/a VerbosePkgLists' /etc/pacman.conf
fi

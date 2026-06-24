echo "Ensure all indexes and packages are up to date"

omybuntu-update-keyring
omybuntu-refresh-pacman
sudo pacman -Syu --noconfirm

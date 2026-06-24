echo "Move Omybuntu Package Repository after Arch core/extra/multilib and remove AUR"

omybuntu-refresh-pacman
sudo pacman -Syu --noconfirm

echo "Prevent kernel upgrades from making current modules unavailable"

omybuntu-pkg-add kernel-modules-hook
sudo systemctl enable --now linux-modules-cleanup.service

# Enable the grub-btrfs daemon to automatically update grub when timeshift creates a snapshot
# Since this runs in post-install, systemctl enable is appropriate
sudo systemctl enable grub-btrfsd.service || true
sudo systemctl start grub-btrfsd.service || true

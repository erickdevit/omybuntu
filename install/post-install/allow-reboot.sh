# Allow passwordless reboot for the installer - removed in first-run
# In ISO builds the chroot user is root, but the live session user is 'ubuntu'
SUDOERS_USER="${OMYBUNTU_ISO_BUILD:+ubuntu}"
SUDOERS_USER="${SUDOERS_USER:-$USER}"

sudo tee /etc/sudoers.d/99-omybuntu-installer-reboot > /dev/null <<EOF
$SUDOERS_USER ALL=(ALL) NOPASSWD: /usr/bin/reboot
EOF
sudo chmod 440 /etc/sudoers.d/99-omybuntu-installer-reboot

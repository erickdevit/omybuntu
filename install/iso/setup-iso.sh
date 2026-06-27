echo "Preparing Omybuntu Live ISO Environment..."

# Block gdm3 and gnome-session from ever being installed as dependencies
sudo mkdir -p /etc/apt/preferences.d
cat <<EOF | sudo tee /etc/apt/preferences.d/no-gnome-session > /dev/null
# Omybuntu uses Hyprland via SDDM; GNOME session manager is not wanted
Package: gdm3
Pin: release *
Pin-Priority: -1

Package: gnome-session
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop-minimal
Pin: release *
Pin-Priority: -1
EOF

# Purge them if they somehow got pulled in as transitive dependencies
for pkg in gdm3 gnome-session ubuntu-desktop ubuntu-desktop-minimal; do
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    sudo apt-get purge -y "$pkg"
  fi
done

# Create the autostart directory for skel (so the live user gets it)
sudo mkdir -p /etc/skel/.config/autostart
cat <<EOF | sudo tee /etc/skel/.config/autostart/omybuntu-installer.desktop > /dev/null
[Desktop Entry]
Type=Application
Name=Install Omybuntu
Exec=ghostty -e omybuntu-setup-install
Icon=system-software-install
Categories=System;
Terminal=false
EOF

# Ensure SDDM is the active display manager and is enabled
sudo systemctl enable sddm.service 2>/dev/null || true
sudo systemctl disable gdm.service gdm3.service 2>/dev/null || true

# Ensure live autologin is configured for the 'ubuntu' user (Casper standard)
# This runs after install.sh so it is the definitive final state
sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null
[Autologin]
User=ubuntu
Session=omybuntu

[Theme]
Current=omybuntu
EOF

echo "Live ISO environment prepared successfully."

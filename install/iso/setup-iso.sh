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

# ---------------------------------------------------------------------------
# Populate /etc/skel/ with root configs so the casper live user 'ubuntu'
# gets a fully configured Hyprland session on first boot.
# install.sh runs as root in the chroot, so all configs land in /root/.
# Casper creates /home/ubuntu/ by copying /etc/skel/ at boot.
# ---------------------------------------------------------------------------
echo "Copying configs to /etc/skel/ for the live user..."

# Core config dirs
sudo mkdir -p /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/state/omybuntu

# Copy all user configs from /root/.config/ to /etc/skel/.config/
sudo cp -a /root/.config/. /etc/skel/.config/

# Copy user local data (icons, applications, etc.)
if [[ -d /root/.local/share ]]; then
  sudo cp -a /root/.local/share/. /etc/skel/.local/share/
fi

# Copy local binaries (elephant, walker, TUI apps) to skel
if [[ -d /root/.local/bin ]]; then
  sudo cp -a /root/.local/bin/. /etc/skel/.local/bin/
fi

# Copy state files (toggles, first-run marker, etc.)
if [[ -d /root/.local/state/omybuntu ]]; then
  sudo mkdir -p /etc/skel/.local/state/omybuntu
  sudo cp -a /root/.local/state/omybuntu/. /etc/skel/.local/state/omybuntu/
fi

# Copy .bashrc
[[ -f /root/.bashrc ]] && sudo cp /root/.bashrc /etc/skel/.bashrc

# Create symlink: ~/.local/share/omybuntu -> /opt/omybuntu
# The bashrc sources from ~/.local/share/omybuntu; in the ISO the code is at /opt/omybuntu
sudo mkdir -p /etc/skel/.local/share
sudo ln -snf /opt/omybuntu /etc/skel/.local/share/omybuntu

# Remove any hardcoded /root paths that leaked into skel configs
for dir in /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/bin; do
  if [[ -d $dir ]]; then
    sudo grep -rl "/root/" "$dir" 2>/dev/null | while read -r f; do
      sudo sed -i 's|/root/|/home/ubuntu/|g' "$f"
    done
  fi
done

# Remove Chromium singleton lock that may have been created during install
sudo rm -rf /etc/skel/.config/chromium/SingletonLock
sudo rm -rf /etc/skel/.config/google-chrome/SingletonLock

echo "Skel populated. Live user 'ubuntu' will inherit full Omybuntu configuration."


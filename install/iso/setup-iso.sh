#!/bin/bash

set -euo pipefail

export OMYBUNTU_PATH="${OMYBUNTU_PATH:-/opt/omybuntu}"
export OMYBUNTU_INSTALL="${OMYBUNTU_INSTALL:-$OMYBUNTU_PATH/install}"
export PATH="$OMYBUNTU_PATH/bin:$PATH"

echo "Preparing Omybuntu Live ISO Environment..."

# Block gdm3, gnome-session, and unwanted themes from ever being installed as dependencies
sudo mkdir -p /etc/apt/preferences.d
cat <<EOF | sudo tee /etc/apt/preferences.d/no-gnome-session > /dev/null
# Omybuntu uses Hyprland via SDDM; GNOME session manager is not wanted
Package: gdm3
Pin: release *
Pin-Priority: -1

Package: gnome-session
Pin: release *
Pin-Priority: -1

Package: ubuntu-session
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop
Pin: release *
Pin-Priority: -1

Package: ubuntu-desktop-minimal
Pin: release *
Pin-Priority: -1

Package: budgie-sddm-theme
Pin: release *
Pin-Priority: -1

Package: sddm-theme-breeze
Pin: release *
Pin-Priority: -1
EOF

# Purge them if they somehow got pulled in as transitive dependencies
for pkg in gdm3 gnome-session ubuntu-session ubuntu-desktop ubuntu-desktop-minimal budgie-sddm-theme sddm-theme-breeze; do
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "$pkg"
  fi
done
sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge

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

# Ensure SDDM assets, session, and greeter compositor are present even if
# package postinst scripts skipped display-manager setup inside the chroot.
omybuntu-refresh-sddm
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop
sudo cp "$OMYBUNTU_PATH/default/sddm/hyprland.conf" /usr/share/sddm/hyprland.conf
sudo rm -f /usr/share/sddm/hyprland.lua
for session in hyprland.desktop hyprland-uwsm.desktop ubuntu.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    sudo rm -f "/usr/share/wayland-sessions/$session"
  fi
done

# Ensure live autologin is configured for the 'ubuntu' user (Casper standard)
# This runs after install.sh so it is the definitive final state
sudo mkdir -p /etc/sddm.conf.d
sudo rm -f /etc/sddm.conf.d/10-wayland.conf
sudo rm -f /etc/sddm.conf.d/autologin.conf
sudo rm -f /etc/sddm.conf.d/50-ubuntu-budgie.conf

cat <<EOF | sudo tee /etc/sddm.conf.d/99-omybuntu.conf > /dev/null
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf

[Autologin]
User=ubuntu
Session=omybuntu

[Theme]
Current=omybuntu
EOF

# Make the live user deterministic for casper-based boots.
cat <<EOF | sudo tee /etc/casper.conf > /dev/null
export USERNAME="ubuntu"
export USERFULLNAME="Omybuntu Live User"
export HOST="omybuntu"
export BUILD_SYSTEM="Ubuntu"
EOF

# Ensure SDDM is the active display manager and graphical target is reached.
sudo systemctl disable gdm.service gdm3.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/display-manager.service
if [[ -f /usr/lib/systemd/system/sddm.service ]]; then
  sddm_unit="/usr/lib/systemd/system/sddm.service"
elif [[ -f /lib/systemd/system/sddm.service ]]; then
  sddm_unit="/lib/systemd/system/sddm.service"
else
  echo "sddm.service not found in the live chroot" >&2
  exit 1
fi
sudo mkdir -p /etc/systemd/system/graphical.target.wants
sudo ln -snf "$sddm_unit" /etc/systemd/system/display-manager.service
sudo ln -snf "$sddm_unit" /etc/systemd/system/graphical.target.wants/sddm.service
if [[ -f /usr/lib/systemd/system/graphical.target ]]; then
  sudo ln -snf /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target
elif [[ -f /lib/systemd/system/graphical.target ]]; then
  sudo ln -snf /lib/systemd/system/graphical.target /etc/systemd/system/default.target
fi
sudo systemctl enable sddm.service 2>/dev/null || true
sudo systemctl set-default graphical.target 2>/dev/null || true

echo "Live ISO environment prepared successfully."

# ---------------------------------------------------------------------------
# Populate /etc/skel/ with root configs so the casper live user 'ubuntu'
# gets a fully configured Hyprland session on first boot.
# install.sh runs as root in the chroot, so all configs land in /root/.
# Casper creates /home/ubuntu/ by copying /etc/skel/ at boot.
# ---------------------------------------------------------------------------
echo "Copying configs to /etc/skel/ for the live user..."

# Core config dirs
sudo mkdir -p /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/bin /etc/skel/.local/state/omybuntu

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
    while read -r f; do
      sudo sed -i 's|/root/|/home/ubuntu/|g' "$f"
    done < <(sudo grep -rl "/root/" "$dir" 2>/dev/null || true)
  fi
done

# Remove Chromium singleton lock that may have been created during install
sudo rm -rf /etc/skel/.config/chromium/SingletonLock
sudo rm -rf /etc/skel/.config/google-chrome/SingletonLock

# Refresh Plymouth/SDDM configurations and rebuild initramfs inside chroot
echo "Refreshing Plymouth, SDDM, and rebuilding initramfs..."
omybuntu-refresh-plymouth
omybuntu-refresh-sddm
update-initramfs -u

echo "Skel populated. Live user 'ubuntu' will inherit full Omybuntu configuration."

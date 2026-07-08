#!/bin/bash

set -euo pipefail

export OMYBUNTU_PATH="${OMYBUNTU_PATH:-/opt/omybuntu}"
export OMYBUNTU_INSTALL="${OMYBUNTU_INSTALL:-$OMYBUNTU_PATH/install}"
LIVE_USER="${OMYBUNTU_LIVE_USER:-omybuntu}"
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

# Keep the live ISO lean and aligned with the Alacritty-first default. Chrome is
# intentionally kept because the live environment must always include a browser.
for pkg in ghostty typora; do
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
Exec=/opt/omybuntu/bin/omybuntu-launch-tui /opt/omybuntu/bin/omybuntu-setup-install
Icon=system-software-install
Categories=System;
Terminal=false
EOF

cat <<EOF | sudo tee /etc/skel/.config/autostart/omybuntu-live-session-setup.desktop > /dev/null
[Desktop Entry]
Type=Application
Name=Omybuntu Live Session Setup
Exec=/usr/local/bin/omybuntu-live-session-setup
NoDisplay=true
Terminal=false
EOF

sudo ln -snf /opt/omybuntu/bin/omybuntu-live-session-setup /usr/local/bin/omybuntu-live-session-setup

cat <<EOF | sudo tee /etc/sudoers.d/99-omybuntu-live-installer > /dev/null
$LIVE_USER ALL=(ALL) NOPASSWD: /usr/local/bin/omybuntu-installer
EOF
sudo chmod 0440 /etc/sudoers.d/99-omybuntu-live-installer

# Ensure SDDM assets, session, and greeter compositor are present even if
# package postinst scripts skipped display-manager setup inside the chroot.
omybuntu-refresh-sddm
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/hyprland.desktop" /usr/share/wayland-sessions/hyprland.desktop
sudo cp "$OMYBUNTU_PATH/default/sddm/hyprland.conf" /usr/share/sddm/hyprland.conf
sudo rm -f /usr/share/sddm/hyprland.lua
for session in hyprland-uwsm.desktop ubuntu.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    sudo rm -f "/usr/share/wayland-sessions/$session"
  fi
done

# Ensure live autologin is configured for the Omybuntu live user.
# This runs after install.sh so it is the definitive final state
sudo mkdir -p /etc/sddm.conf.d
sudo rm -f /etc/sddm.conf.d/10-wayland.conf
sudo rm -f /etc/sddm.conf.d/autologin.conf
sudo rm -f /etc/sddm.conf.d/50-ubuntu-budgie.conf
sudo rm -f /etc/sddm.conf.d/99-omybuntu.conf

# Live ISO should boot straight into Hyprland; SDDM only appears after logout.
cat <<EOF | sudo tee /etc/sddm.conf.d/zz-omybuntu-live.conf > /dev/null
[General]
DisplayServer=wayland
DefaultSession=omybuntu

[Wayland]
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf

[Autologin]
User=$LIVE_USER
Session=omybuntu
Relogin=true

[Theme]
Current=omybuntu
EOF

sudo sed -i '/pam_faillock\.so/d' /etc/pam.d/sddm-autologin 2>/dev/null || true

# Make the live user deterministic for casper-based boots.
cat <<EOF | sudo tee /etc/casper.conf > /dev/null
export USERNAME="$LIVE_USER"
export USERFULLNAME="Omybuntu Live User"
export HOST="omybuntu"
export BUILD_SYSTEM="Ubuntu"
EOF

# Casper creates the live user during boot. If a stale locked account leaked into
# the image, clear it so manual login still works with an empty password.
if getent passwd "$LIVE_USER" >/dev/null; then
  sudo passwd -d "$LIVE_USER" 2>/dev/null || true
fi

if getent passwd ubuntu >/dev/null; then
  sudo userdel -r ubuntu 2>/dev/null || sudo userdel ubuntu 2>/dev/null || true
fi
sudo rm -rf /home/ubuntu

sudo install -m 0755 "$OMYBUNTU_PATH/install/iso/casper-bottom/15autologin" \
  /usr/share/initramfs-tools/scripts/casper-bottom/15autologin
sudo install -m 0755 "$OMYBUNTU_PATH/install/iso/casper-bottom/26omybuntu-sddm-autologin" \
  /usr/share/initramfs-tools/scripts/casper-bottom/26omybuntu-sddm-autologin
sudo rm -f /usr/share/initramfs-tools/scripts/casper-bottom/16omybuntu-sddm-autologin

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
# Populate /etc/skel/ with root configs so the casper live user
# gets a fully configured Hyprland session on first boot.
# install.sh runs as root in the chroot, so all configs land in /root/.
# Casper creates the live home by copying /etc/skel/ at boot.
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
root_path_files=$(mktemp)
for dir in /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/bin; do
  if [[ -d $dir ]]; then
    sudo grep -rl "/root/" "$dir" >> "$root_path_files" 2>/dev/null || true
  fi
done

while read -r f; do
  [[ -n $f ]] || continue
  sudo sed -i "s|/root/|/home/$LIVE_USER/|g" "$f"
done < "$root_path_files"
rm -f "$root_path_files"

# The root install also creates absolute symlinks for current theme assets and
# enabled user services. Text replacement above does not touch symlink targets.
skel_links=$(mktemp)
sudo find /etc/skel -type l -print0 > "$skel_links" 2>/dev/null || true
while IFS= read -r -d '' link; do
  target=$(sudo readlink "$link")
  if [[ $target == /root/* ]]; then
    sudo ln -snf "/home/$LIVE_USER/${target#/root/}" "$link"
  fi
done < "$skel_links"
rm -f "$skel_links"

for gtk_version in gtk-3.0 gtk-4.0; do
  bookmark_file="/etc/skel/.config/$gtk_version/bookmarks"
  if [[ -f $bookmark_file ]]; then
    bookmark_tmp=$(mktemp)
    sudo awk '!seen[$0]++' "$bookmark_file" >"$bookmark_tmp"
    sudo install -m 0644 "$bookmark_tmp" "$bookmark_file"
    rm -f "$bookmark_tmp"
  fi
done

live_hypr_autostart="/etc/skel/.config/hypr/autostart.conf"
sudo mkdir -p /etc/skel/.config/hypr
sudo touch "$live_hypr_autostart"
sudo sed -i '/^# Live ISO startup$/d;/omybuntu-live-session-setup/d;/omybuntu-setup-install/d' "$live_hypr_autostart"
cat <<EOF | sudo tee -a "$live_hypr_autostart" >/dev/null

# Live ISO startup
exec-once = /usr/local/bin/omybuntu-live-session-setup
exec-once = sleep 3 && /opt/omybuntu/bin/omybuntu-launch-tui /opt/omybuntu/bin/omybuntu-setup-install
EOF

# The live username can vary by casper boot path. Keep theme-owned assets
# relative inside the profile so wallpaper startup does not depend on a fixed home path.
sudo mkdir -p /etc/skel/.config/omybuntu/current
if [[ -f /etc/skel/.config/omybuntu/current/theme/backgrounds/omybuntu.png ]]; then
  sudo ln -snf "theme/backgrounds/omybuntu.png" /etc/skel/.config/omybuntu/current/background
fi

# Write GTK settings files directly for the live user. The install-time
# gsettings calls run as root in a chroot and do not reliably seed dconf for the
# casper user.
if [[ -f /etc/skel/.config/omybuntu/current/theme/light.mode ]]; then
  live_color_scheme="prefer-light"
  live_gtk_theme="Adwaita"
  live_gtk_prefer_dark=0
  live_cursor_theme="volantes_cursors"
else
  live_color_scheme="prefer-dark"
  live_gtk_theme="Adwaita-dark"
  live_gtk_prefer_dark=1
  live_cursor_theme="volantes_light_cursors"
fi

if [[ -f /etc/skel/.config/omybuntu/current/theme/icons.theme ]]; then
  live_icon_theme=$(sudo cat /etc/skel/.config/omybuntu/current/theme/icons.theme)
else
  live_icon_theme="Yaru-blue"
fi

for gtk_version in gtk-3.0 gtk-4.0; do
  sudo mkdir -p "/etc/skel/.config/$gtk_version"
  cat <<EOF | sudo tee "/etc/skel/.config/$gtk_version/settings.ini" >/dev/null
[Settings]
gtk-theme-name=$live_gtk_theme
gtk-icon-theme-name=$live_icon_theme
gtk-cursor-theme-name=$live_cursor_theme
gtk-application-prefer-dark-theme=$live_gtk_prefer_dark
EOF
done

sudo mkdir -p /etc/skel/.icons/default
cat <<EOF | sudo tee /etc/skel/.icons/default/index.theme >/dev/null
[Icon Theme]
Inherits=$live_cursor_theme
EOF

sudo mkdir -p /etc/dconf/db/local.d
cat <<EOF | sudo tee /etc/dconf/db/local.d/00-omybuntu-live-theme >/dev/null
[org/gnome/desktop/interface]
color-scheme='$live_color_scheme'
gtk-theme='$live_gtk_theme'
icon-theme='$live_icon_theme'
cursor-theme='$live_cursor_theme'
EOF
sudo dconf update 2>/dev/null || true

# Remove launchers that are implementation details or not part of the live ISO.
live_hidden_desktops=(
  "com.mitchellh.ghostty.desktop"
  "ghostty.desktop"
  "typora.desktop"
  "Docker.desktop"
  "Google Contacts.desktop"
  "Google Maps.desktop"
  "Google Messages.desktop"
  "Google Photos.desktop"
  "display-im6.desktop"
  "display-im6.q16.desktop"
  "ImageMagick.desktop"
  "org.imagemagick.ImageMagick.desktop"
  "nm-connection-editor.desktop"
  "gnome-network-panel.desktop"
  "gnome-language-selector.desktop"
  "ibus-setup-table.desktop"
  "org.freedesktop.IBus.Setup.desktop"
  "org.freedesktop.IBus.Panel.Emojier.desktop"
  "org.freedesktop.IBus.Panel.Extension.Gtk3.desktop"
  "org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop"
)

for desktop in "${live_hidden_desktops[@]}"; do
  sudo rm -f "/etc/skel/.local/share/applications/$desktop"
  sudo rm -f "/root/.local/share/applications/$desktop"
  sudo rm -f "/usr/share/applications/$desktop"
  sudo rm -f "/usr/local/share/applications/$desktop"
done

while IFS= read -r -d '' desktop; do
  sudo rm -f "$desktop"
done < <(sudo find /etc/skel/.local/share/applications /root/.local/share/applications /usr/share/applications /usr/local/share/applications \
  -maxdepth 1 -type f \( -iname "*magick*.desktop" -o -iname "*im6*.desktop" \) -print0 2>/dev/null || true)

sudo rm -rf /etc/skel/.config/ghostty /root/.config/ghostty
sudo rm -f /etc/skel/.config/xdg-terminals.list /root/.config/xdg-terminals.list
cat <<EOF | sudo tee /etc/skel/.config/xdg-terminals.list >/dev/null
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
Alacritty.desktop
EOF

# Remove Chromium singleton lock that may have been created during install
sudo rm -rf /etc/skel/.config/chromium/SingletonLock
sudo rm -rf /etc/skel/.config/google-chrome/SingletonLock

# Refresh Plymouth/SDDM configurations and rebuild initramfs inside chroot
echo "Refreshing Plymouth, SDDM, and rebuilding initramfs..."
omybuntu-refresh-plymouth
omybuntu-refresh-sddm
update-initramfs -u

echo "Skel populated. Live user '$LIVE_USER' will inherit full Omybuntu configuration."

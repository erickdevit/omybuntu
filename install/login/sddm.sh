# Install omybuntu SDDM theme
omybuntu-refresh-sddm

# Setup SDDM login service
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop
sudo cp "$OMYBUNTU_PATH/default/sddm/hyprland.conf" /usr/share/sddm/hyprland.conf
sudo rm -f /usr/share/sddm/hyprland.lua

# Hide other desktop sessions so only Omybuntu is listed in SDDM
for session in hyprland.desktop hyprland-uwsm.desktop ubuntu.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    sudo rm -f "/usr/share/wayland-sessions/$session"
  fi
done

sudo mkdir -p /etc/sddm.conf.d
# Remove package overrides from downstream (e.g. ubuntu budgie) and old config files
sudo rm -f /etc/sddm.conf.d/10-wayland.conf
sudo rm -f /etc/sddm.conf.d/autologin.conf
sudo rm -f /etc/sddm.conf.d/50-ubuntu-budgie.conf

cat <<EOF | sudo tee /etc/sddm.conf.d/99-omybuntu.conf >/dev/null
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf

[Autologin]
User=$USER
Session=omybuntu

[Theme]
Current=omybuntu
EOF

# Prevent password-based SDDM logins from creating an encrypted login keyring
# (which conflicts with the passwordless Default_keyring used for auto-unlock)
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl disable gdm.service gdm3.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/display-manager.service
sudo systemctl enable sddm.service || true
sudo systemctl set-default graphical.target 2>/dev/null || true

# Install omybuntu SDDM theme
omybuntu-refresh-sddm

# Setup SDDM login service
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/hyprland.desktop" /usr/share/wayland-sessions/hyprland.desktop
sudo cp "$OMYBUNTU_PATH/default/sddm/hyprland.conf" /usr/share/sddm/hyprland.conf
sudo rm -f /usr/share/sddm/hyprland.lua

# Hide other desktop sessions so only Omybuntu is listed in SDDM.
# Keep hyprland.desktop as a valid NoDisplay launch target for uwsm.
for session in hyprland-uwsm.desktop ubuntu.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    sudo rm -f "/usr/share/wayland-sessions/$session"
  fi
done

sudo mkdir -p /etc/sddm.conf.d
# Remove package overrides from downstream (e.g. ubuntu budgie) and old config files
sudo rm -f /etc/sddm.conf.d/10-wayland.conf
sudo rm -f /etc/sddm.conf.d/autologin.conf
sudo rm -f /etc/sddm.conf.d/50-ubuntu-budgie.conf
sudo rm -f /etc/sddm.conf.d/zz-omybuntu-live.conf

sddm_autologin_block=""
# Live ISO uses zz-omybuntu-live.conf; chroot installs are finalized after user creation.
if [[ -z ${OMYBUNTU_ISO_BUILD:-} && -z ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
  omybuntu_encrypted_install=false
  if [[ ${OMYBUNTU_ENCRYPTED_INSTALL:-} == "true" ]]; then
    omybuntu_encrypted_install=true
  elif [[ -f /etc/crypttab ]] && grep -qE '^[^#[:space:]]' /etc/crypttab; then
    omybuntu_encrypted_install=true
  fi

  if [[ $omybuntu_encrypted_install == true ]]; then
    autologin_user="${USER:-}"
    if [[ $autologin_user == "root" && -n ${SUDO_USER:-} ]]; then
      autologin_user="$SUDO_USER"
    fi
    if [[ -n $autologin_user && $autologin_user != "root" ]]; then
      sddm_autologin_block="
[Autologin]
User=$autologin_user
Session=omybuntu
Relogin=true"
    fi
  fi
fi

cat <<EOF | sudo tee /etc/sddm.conf.d/99-omybuntu.conf >/dev/null
[General]
DisplayServer=wayland
DefaultSession=omybuntu

[Wayland]
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf
$sddm_autologin_block

[Theme]
Current=omybuntu
EOF

sudo sed -i '/pam_faillock\.so/d' /etc/pam.d/sddm-autologin 2>/dev/null || true

# Prevent password-based SDDM logins from creating an encrypted login keyring
# (which conflicts with the passwordless Default_keyring used for auto-unlock)
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl disable gdm.service gdm3.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/display-manager.service
sudo systemctl enable sddm.service || true
sudo systemctl set-default graphical.target 2>/dev/null || true

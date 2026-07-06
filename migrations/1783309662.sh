echo "Consolidate SDDM configurations to 99-omybuntu.conf, delete obsolete overrides, and hide alternative desktop sessions"

if omybuntu-pkg-present sddm; then
  # Hide alternative sessions in SDDM greeter
  for session in hyprland.desktop hyprland-uwsm.desktop ubuntu.desktop; do
    if [[ -f /usr/share/wayland-sessions/$session ]]; then
      sudo rm -f "/usr/share/wayland-sessions/$session"
    fi
  done

  sudo mkdir -p /etc/sddm.conf.d
  # Purge older configs and budgie overrides
  sudo rm -f /etc/sddm.conf.d/10-wayland.conf
  sudo rm -f /etc/sddm.conf.d/autologin.conf
  sudo rm -f /etc/sddm.conf.d/50-ubuntu-budgie.conf

  autologin_user="${USER:-ubuntu}"
  if [[ $autologin_user == "root" && -n ${SUDO_USER:-} ]]; then
    autologin_user="$SUDO_USER"
  fi

  cat <<EOF | sudo tee /etc/sddm.conf.d/99-omybuntu.conf >/dev/null
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf

[Autologin]
User=$autologin_user
Session=omybuntu

[Theme]
Current=omybuntu
EOF

  if omybuntu-cmd-present omybuntu-refresh-sddm; then
    omybuntu-refresh-sddm
  fi
fi

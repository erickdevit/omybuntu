echo "Use Omybuntu UWSM session without graphical.target startup wait"

sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop

if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  sudo sed -i 's/^Session=hyprland-uwsm$/Session=omybuntu/' /etc/sddm.conf.d/autologin.conf
fi

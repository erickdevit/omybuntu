echo "Install the centered Plymouth spinner and launch Hyprland through its watchdog"

if omybuntu-cmd-present omybuntu-refresh-plymouth; then
  omybuntu-refresh-plymouth
fi

sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/omybuntu.desktop" /usr/share/wayland-sessions/omybuntu.desktop
sudo cp "$OMYBUNTU_PATH/default/wayland-sessions/hyprland.desktop" /usr/share/wayland-sessions/hyprland.desktop

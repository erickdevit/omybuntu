# Remove package-provided launchers that should not appear in Walker.
# Elephant lists every .desktop file it finds; user Hidden=true stubs are not enough.

launcher_clutter_desktops=(
  foot.desktop
  footclient.desktop
  foot-server.desktop
  org.fcitx.Fcitx5.desktop
  org.fcitx.fcitx5-migrator.desktop
  org.fcitx.fcitx5-config-qt.desktop
  org.fcitx.fcitx5-qt5-gui-wrapper.desktop
  org.fcitx.fcitx5-qt6-gui-wrapper.desktop
  fcitx5-configtool.desktop
  fcitx5-wayland-launcher.desktop
  im-config.desktop
  org.quickshell.desktop
  com.mitchellh.ghostty.desktop
  ghostty.desktop
  typora.desktop
  Docker.desktop
  "Google Contacts.desktop"
  "Google Maps.desktop"
  "Google Messages.desktop"
  "Google Photos.desktop"
  display-im6.desktop
  display-im6.q16.desktop
  ImageMagick.desktop
  org.imagemagick.ImageMagick.desktop
  nm-connection-editor.desktop
  gnome-network-panel.desktop
  gnome-language-selector.desktop
  ibus-setup-table.desktop
  org.freedesktop.IBus.Setup.desktop
  org.freedesktop.IBus.Panel.Emojier.desktop
  org.freedesktop.IBus.Panel.Extension.Gtk3.desktop
  org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop
  org.gnome.Papers.desktop
  org.gnome.Papers-previewer.desktop
)

for desktop in "${launcher_clutter_desktops[@]}"; do
  sudo rm -f "/usr/share/applications/$desktop"
  sudo rm -f "/usr/local/share/applications/$desktop"
done

while IFS= read -r -d '' desktop; do
  sudo rm -f "$desktop"
done < <(sudo find /usr/share/applications /usr/local/share/applications \
  -maxdepth 1 -type f \( -iname "*magick*.desktop" -o -iname "*im6*.desktop" \) -print0 2>/dev/null || true)

if omybuntu-pkg-present foot; then
  omybuntu-pkg-drop foot
fi

if omybuntu-pkg-present papers; then
  omybuntu-pkg-drop papers
fi

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
)

for desktop in "${launcher_clutter_desktops[@]}"; do
  sudo rm -f "/usr/share/applications/$desktop"
  sudo rm -f "/usr/local/share/applications/$desktop"
done

if omybuntu-pkg-present foot; then
  omybuntu-pkg-drop foot
fi
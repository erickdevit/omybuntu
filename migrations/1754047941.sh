echo "Add icon theme coloring"

if ! omybuntu-pkg-present yaru-icon-theme &>/dev/null && ! omybuntu-pkg-present yaru-theme-icon &>/dev/null; then
  omybuntu-pkg-add yaru-theme-icon || omybuntu-pkg-add yaru-icon-theme || true

  if [[ -f ~/.config/omybuntu/current/theme/icons.theme ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "$(<~/.config/omybuntu/current/theme/icons.theme)"
  fi
fi

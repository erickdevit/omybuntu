echo "Switching to polkit-gnome for better fingerprint authentication compatibility"

if ! command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null && \
   ! command -v /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &>/dev/null; then
  omybuntu-pkg-add policykit-1-gnome || omybuntu-pkg-add polkit-gnome || true
  systemctl --user stop hyprpolkitagent || true
  systemctl --user disable hyprpolkitagent || true
  omybuntu-pkg-drop hyprpolkitagent || true
  if [[ -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
    setsid /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
  elif [[ -f /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ]]; then
    setsid /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
  fi
fi

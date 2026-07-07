echo "Keep hypridle running when idle locking is disabled"

flag_dir="$HOME/.local/state/omybuntu/toggles"
flag="$flag_dir/idle-lock-off"
hypridle_conf="$HOME/.config/hypr/hypridle.conf"

if [[ -f $hypridle_conf ]]; then
  sed -i 's/on-timeout = omybuntu-system-lock/on-timeout = omybuntu-toggle-enabled idle-lock-off || omybuntu-system-lock/' "$hypridle_conf"
  sed -i 's/on-timeout = systemctl suspend/on-timeout = omybuntu-toggle-enabled suspend-off || systemctl suspend/' "$hypridle_conf"
fi

if ! pgrep -x hypridle >/dev/null; then
  mkdir -p "$flag_dir"
  touch "$flag"

  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && omybuntu-cmd-present hypridle; then
    if omybuntu-cmd-present uwsm-app; then
      uwsm-app -- hypridle >/dev/null 2>&1 &
    else
      hypridle >/dev/null 2>&1 &
    fi
  fi
fi

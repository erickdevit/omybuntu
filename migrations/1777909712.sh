echo "Remove stale Xe Panel Replay kernel cmdline from Dell XPS Panther Lake systems"

DEFAULT_LIMINE="/etc/default/limine"

if omybuntu-hw-match "XPS" && omybuntu-hw-intel-ptl; then
  if [[ -f $DEFAULT_LIMINE ]] && grep -q 'xe\.enable_panel_replay' "$DEFAULT_LIMINE"; then
    sudo sed -i '/^KERNEL_CMDLINE.*xe\.enable_panel_replay/d' "$DEFAULT_LIMINE"
    if omybuntu-cmd-present limine-update; then
      sudo limine-update
    fi
  fi
fi

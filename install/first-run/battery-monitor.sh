if omybuntu-battery-present; then
  powerprofilesctl set balanced || true

  # Enable battery monitoring timer for low battery notifications
  systemctl --user enable --now omybuntu-battery-monitor.timer
else
  powerprofilesctl set performance || true
fi

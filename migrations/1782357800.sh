echo "Disable Apport crash reporter and clear old crash reports to prevent stuck notifications"

if [[ -f /etc/default/apport ]]; then
  sudo sed -i 's/enabled=1/enabled=0/' /etc/default/apport
fi

if systemctl is-active --quiet apport; then
  sudo systemctl stop apport 2>/dev/null || true
  sudo systemctl disable apport 2>/dev/null || true
fi

sudo rm -f /var/crash/*

systemctl --user stop update-notifier-crash.path update-notifier-crash.service 2>/dev/null || true
systemctl --user mask update-notifier-crash.path update-notifier-crash.service 2>/dev/null || true

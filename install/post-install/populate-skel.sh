echo "Populating /etc/skel with user configuration files"

mkdir -p /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/state/omybuntu

if [[ -d /root/.config ]]; then
  cp -a /root/.config/. /etc/skel/.config/
fi

if [[ -d /root/.local/share ]]; then
  cp -a /root/.local/share/. /etc/skel/.local/share/
fi

if [[ -d /root/.local/state/omybuntu ]]; then
  mkdir -p /etc/skel/.local/state
  cp -a /root/.local/state/omybuntu /etc/skel/.local/state/omybuntu
fi

if [[ -d /root/.local/bin ]]; then
  mkdir -p /etc/skel/.local/bin
  cp -a /root/.local/bin/. /etc/skel/.local/bin/
fi

if [[ -f /root/.bashrc ]]; then
  cp /root/.bashrc /etc/skel/.bashrc
fi

# Ensure correct links/pathing for Omybuntu share
mkdir -p /etc/skel/.local/share
ln -snf /opt/omybuntu /etc/skel/.local/share/omybuntu

# Remove socket/lock files if any
rm -rf /etc/skel/.config/chromium/SingletonLock
rm -rf /etc/skel/.config/google-chrome/SingletonLock

# Disable globally enabled systemd user services that we launch manually in Hyprland
echo "Disabling globally auto-started systemd user services..."
systemctl --global disable waybar.service || true
systemctl --global disable mako.service || true
systemctl --global disable hypridle.service || true


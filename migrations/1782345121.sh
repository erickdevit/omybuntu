echo "Configure AppArmor override for notify-send and install satty screenshot editor"

# 1. Install satty if missing
if omybuntu-cmd-missing satty; then
  echo "Downloading and installing satty..."
  mkdir -p /tmp/satty_extract
  wget -qO- https://github.com/Satty-org/Satty/releases/download/v0.21.1/satty-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C /tmp/satty_extract
  if [[ -f /tmp/satty_extract/satty ]]; then
    mv /tmp/satty_extract/satty /usr/local/bin/satty
    chmod +x /usr/local/bin/satty
  fi
  rm -rf /tmp/satty_extract
fi

# 2. Configure AppArmor override for notify-send
if omybuntu-cmd-present apparmor_parser && [[ -d /etc/apparmor.d/local ]]; then
  LOCAL_CONF="/etc/apparmor.d/local/notify-send"

  if ! grep -q "member={GetCapabilities,CloseNotification}" "$LOCAL_CONF" 2>/dev/null; then
    mkdir -p /etc/apparmor.d/local
    cat << 'EOF' > "$LOCAL_CONF"
    dbus (send)
        bus=session
        path=/org/freedesktop/Notifications
        interface=org.freedesktop.Notifications
        member={GetCapabilities,CloseNotification},

    dbus (receive)
        bus=session
        path=/org/freedesktop/Notifications
        interface=org.freedesktop.Notifications,
EOF
    apparmor_parser -r /etc/apparmor.d/notify-send 2>/dev/null || true
  fi
fi

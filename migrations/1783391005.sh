echo "Disable SDDM autologin on non-encrypted installs so the greeter appears at boot"

if ! omybuntu-pkg-present sddm; then
  return 0
fi

if [[ -f /etc/crypttab ]] && grep -qE '^[^#[:space:]]' /etc/crypttab; then
  return 0
fi

if [[ -f /etc/sddm.conf.d/zz-omybuntu-live.conf ]]; then
  return 0
fi

if [[ -f /etc/sddm.conf.d/99-omybuntu.conf ]]; then
  sudo sed -i '/^\[Autologin\]/,/^$/d' /etc/sddm.conf.d/99-omybuntu.conf
fi

sudo rm -f /etc/sddm.conf.d/autologin.conf
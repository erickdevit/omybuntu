echo "Add thunderbolt support to boot image"

omybuntu-pkg-add bolt

if [[ -d /etc/mkinitcpio.conf.d ]]; then
  if [[ ! -f /etc/mkinitcpio.conf.d/thunderbolt_module.conf ]]; then
    sudo tee /etc/mkinitcpio.conf.d/thunderbolt_module.conf <<EOF >/dev/null
MODULES+=(thunderbolt)
EOF
  fi
fi

if [[ -f /etc/initramfs-tools/modules ]]; then
  if ! grep -qxF "thunderbolt" /etc/initramfs-tools/modules; then
    echo "thunderbolt" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
    if omybuntu-cmd-present update-initramfs; then
      sudo update-initramfs -u
    fi
  fi
fi

if omybuntu-cmd-present limine-update; then
  sudo limine-update
fi

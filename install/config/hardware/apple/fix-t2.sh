# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
if lspci -nn | grep -q "106b:180[12]"; then
  echo "Detected MacBook with T2 chip. Installing support items..."

  omybuntu-pkg-add \
    linux-t2 \
    linux-t2-headers \
    apple-t2-audio-config \
    apple-bcm-firmware \
    t2fanrd \
    tiny-dfr

  # Add user to video group (required for tiny-dfr to access /dev/dri devices)
  sudo usermod -aG video ${USER}

  # Enable T2 services
  sudo systemctl enable t2fanrd.service
  sudo systemctl enable tiny-dfr.service

  echo "apple-bce" | sudo tee /etc/modules-load.d/t2.conf >/dev/null
  echo "hci_bcm4377" | sudo tee -a /etc/modules-load.d/t2.conf >/dev/null

  # Add T2 modules to initramfs (Ubuntu uses initramfs-tools, not mkinitcpio)
  for mod in apple-bce usbhid hid_apple hid_generic xhci_pci xhci_hcd; do
    grep -qxF "$mod" /etc/initramfs-tools/modules 2>/dev/null || echo "$mod" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
  done
  sudo update-initramfs -u

  cat <<EOF | sudo tee /etc/modprobe.d/brcmfmac.conf >/dev/null
# Fix for T2 MacBook WiFi connectivity issues
options brcmfmac feature_disable=0x82000
EOF

  if [[ -f /etc/default/grub ]]; then
    current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
    if ! echo "$current_cmdline" | grep -q "intel_iommu=on iommu=pt pcie_ports=compat"; then
      new_cmdline=$(echo "$current_cmdline" | sed 's/ $//')
      new_cmdline="$new_cmdline intel_iommu=on iommu=pt pcie_ports=compat"
      sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=).*/\1"'"$new_cmdline"'"/' /etc/default/grub
    fi
  fi

  cat <<EOF | sudo tee /etc/t2fand.conf >/dev/null
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
EOF
fi

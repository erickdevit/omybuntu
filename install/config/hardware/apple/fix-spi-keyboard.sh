# Detect MacBook models that need SPI keyboard modules
product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
if [[ $product_name =~ MacBook[89],1|MacBook1[02],1|MacBookPro13,[123]|MacBookPro14,[123] ]]; then
  echo "Detected MacBook with SPI keyboard"

  omybuntu-pkg-add macbook12-spi-driver-dkms
  # Add modules to initramfs (Ubuntu uses initramfs-tools, not mkinitcpio)
  if [[ $product_name == "MacBook8,1" ]]; then
    mods=(applespi spi_pxa2xx_platform spi_pxa2xx_pci)
  else
    mods=(applespi intel_lpss_pci spi_pxa2xx_platform)
  fi
  for mod in "${mods[@]}"; do
    grep -qxF "$mod" /etc/initramfs-tools/modules 2>/dev/null || echo "$mod" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
  done
  sudo update-initramfs -u
fi

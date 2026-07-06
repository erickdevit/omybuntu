# Enable Flexible Return and Event Delivery on Intel Panther Lake.


if omybuntu-hw-intel-ptl; then
  if [[ -f /etc/default/grub ]]; then
    current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
    if ! echo "$current_cmdline" | grep -q "fred=on"; then
      new_cmdline=$(echo "$current_cmdline" | sed 's/ $//')
      new_cmdline="$new_cmdline fred=on"
      sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=).*/\1"'"$new_cmdline"'"/' /etc/default/grub
    fi
  fi
fi

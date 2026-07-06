echo "Hide shutdown console messages behind Plymouth"

if [[ -f /etc/default/grub ]]; then
  current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
  if ! echo "$current_cmdline" | grep -q "loglevel=0"; then
    new_cmdline=$(echo "$current_cmdline" | sed 's/ $//')
    new_cmdline="$new_cmdline loglevel=0 systemd.show_status=false rd.udev.log_level=0 vt.global_cursor_default=0"
    sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=).*/\1"'"$new_cmdline"'"/' /etc/default/grub
    if omybuntu-cmd-present omybuntu-refresh-grub; then
      omybuntu-refresh-grub
    fi
  fi
fi

if [[ -f /etc/default/limine ]]; then
  sudo sed -i 's/ quiet splash/ quiet splash loglevel=0 systemd.show_status=false rd.udev.log_level=0 vt.global_cursor_default=0/' /etc/default/limine

  if omybuntu-cmd-present limine-mkinitcpio; then
    sudo limine-mkinitcpio
  fi
fi

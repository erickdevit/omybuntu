# Display fix for ASUS ExpertBook B9406 (Panther Lake / Xe3 iGPU).
#
# Panel Replay is Xe3-new, default-on in the xe driver, and has a broken
# exit/wake path on this eDP panel: the panel latches the last-presented
# frame in self-refresh and never wakes for subsequent atomic commits, so
# the screen only updates on a full modeset (e.g. a VT switch). The older
# xe.enable_psr=0 knob does not cover Panel Replay.

if omybuntu-hw-asus-expertbook-b9406; then
  if [[ -f /etc/default/grub ]]; then
    current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
    if ! echo "$current_cmdline" | grep -q "xe.enable_panel_replay=0"; then
      new_cmdline=$(echo "$current_cmdline" | sed 's/ $//')
      new_cmdline="$new_cmdline xe.enable_panel_replay=0"
      sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=).*/\1"'"$new_cmdline"'"/' /etc/default/grub
    fi
  fi
fi

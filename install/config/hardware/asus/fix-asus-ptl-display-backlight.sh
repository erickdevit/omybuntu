# Display backlight fix for ASUS Panther Lake / Xe3 iGPU laptops.
# Enabled only for ExpertBook B9406 and Zenbook UX5406AA for now.
# Other models need confirmation whether the issue exists there too.
#
# The panel's EDID on eDP-1 reads as empty, so xe takes backlight type from
# VBT (which says PWM) but the panel actually wants DPCD AUX backlight.
# Without xe.enable_dpcd_backlight=1, intel_backlight sysfs writes succeed
# but produce no visible change; brightness is effectively binary.

if omybuntu-hw-asus-expertbook-b9406 || omybuntu-hw-asus-zenbook-ux5406aa; then
  if [[ -f /etc/default/grub ]]; then
    current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
    if ! echo "$current_cmdline" | grep -q "xe.enable_dpcd_backlight=1"; then
      new_cmdline=$(echo "$current_cmdline" | sed 's/ $//')
      new_cmdline="$new_cmdline xe.enable_dpcd_backlight=1"
      sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=).*/\1"'"$new_cmdline"'"/' /etc/default/grub
    fi
  fi
fi

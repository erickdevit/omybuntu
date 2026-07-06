echo "Restore stock kernel on non-XPS Panther Lake systems"

if omybuntu-hw-intel-ptl && ! omybuntu-hw-match "XPS"; then
  omybuntu-pkg-add linux linux-headers

  for pkg in linux-ptl linux-ptl-headers; do
    omybuntu-pkg-drop "$pkg" || true
  done

  sudo rm -f /etc/limine-entry-tool.d/intel-panther-lake.conf
  sudo rm -f /etc/limine-entry-tool.d/dell-xps-panther-lake.conf

  if omybuntu-cmd-present limine-update; then
    sudo limine-update
  elif omybuntu-cmd-present update-grub; then
    sudo update-grub
  fi
fi

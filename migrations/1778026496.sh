echo "Install sof-firmware on Intel Panther Lake to restore DSP audio"

# linux-ptl hard-depped sof-firmware, mainline linux only optdeps it, so the
# orphan sweep after migration 1777572869 removed it. Force explicit so a
# subsequent orphan sweep in the same update cycle cannot take it again.

if omybuntu-hw-intel-ptl && ! omybuntu-hw-match "XPS"; then
  omybuntu-pkg-add sof-firmware || true
  if omybuntu-pkg-present pacman &>/dev/null; then
    sudo pacman -D --asexplicit sof-firmware >/dev/null || true
  elif omybuntu-cmd-present apt-mark; then
    sudo apt-mark manual firmware-sof-signed &>/dev/null || true
  fi
  omybuntu-state set reboot-required
fi

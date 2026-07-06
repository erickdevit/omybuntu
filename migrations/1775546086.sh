echo "Enable Intel LPMD service if installed"

if omybuntu-pkg-present intel-lpmd &>/dev/null; then
  sudo systemctl enable --now intel_lpmd.service
fi

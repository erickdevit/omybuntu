# Install Panther Lake kernel for Dell XPS Panther Lake systems
# The linux-ptl kernel includes audio driver patches not yet in mainline.

if omybuntu-hw-match "XPS" && omybuntu-hw-intel-ptl; then
  echo "Detected Dell XPS Panther Lake, installing PTL kernel..."

  omybuntu-pkg-add linux-ptl linux-ptl-headers
  # Remove generic kernel packages that conflict with PTL kernel (Ubuntu equivalent of pacman -Rdd)
  for pkg in linux-image-generic linux-headers-generic; do
    if omybuntu-pkg-present "$pkg"; then
      sudo apt-get remove -y --allow-remove-essential "$pkg" 2>/dev/null || true
    fi
  done

  sudo mkdir -p /etc/limine-entry-tool.d
  cat <<EOF | sudo tee /etc/limine-entry-tool.d/dell-xps-panther-lake.conf >/dev/null
# Only show Panther Lake kernel in boot menu on Dell XPS Panther Lake
BOOT_ORDER="linux-ptl*, *fallback, Snapshots"
EOF
fi

echo "Migrate legacy NVIDIA GPUs to nvidia-580xx driver (if needed)"

# Only migrate GTX 9xx or 10xx (Pascal/Maxwell)
NVIDIA="$(lspci | grep -i 'nvidia')"
if echo "$NVIDIA" | grep -qE "GTX 9|GTX 10"; then
  if omybuntu-pkg-present pacman &>/dev/null; then
    if ! pacman -Qq | grep -qE '^linux(-[a-z0-9]+)?-headers$'; then
      echo "Error: no linux headers package installed (required for DKMS drivers). Please install the appropriate headers and re-run this migration."
      exit 1
    fi

    # Piping yes to override existing packages
    yes | sudo pacman -S nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils

    # Verify packages were installed
    if ! pacman -Qq nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils &>/dev/null; then
      echo "Error: NVIDIA 580xx driver packages failed to install"
      exit 1
    fi
  else
    # Ubuntu path: check for linux-headers
    if ! dpkg -s "linux-headers-$(uname -r)" &>/dev/null && ! dpkg -s "linux-headers-generic" &>/dev/null; then
      sudo apt-get install -y "linux-headers-$(uname -r)" || true
    fi
    if ! dpkg -l | grep -qE '^ii\s+nvidia-driver-[0-9]+'; then
      omybuntu-pkg-add nvidia-driver || true
    fi
    if ! dpkg -l | grep -qE '^ii\s+nvidia-driver-[0-9]+' && ! omybuntu-pkg-present nvidia-driver &>/dev/null; then
      echo "Error: NVIDIA driver packages failed to install"
      exit 1
    fi
    sudo update-initramfs -u || true
  fi
fi

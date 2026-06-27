if lspci | grep -qi 'nvidia'; then
  if omybuntu-hw-nvidia-gsp; then
    PACKAGES=(nvidia-driver nvidia-utils-common)
    GPU_ARCH="turing_plus"
  elif omybuntu-hw-nvidia-without-gsp; then
    PACKAGES=(nvidia-driver)
    GPU_ARCH="maxwell_pascal_volta"
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU."
    return 0 2>/dev/null || exit 0
  fi

  omybuntu-pkg-add "${PACKAGES[@]}"

  # Configure modprobe for early KMS
  sudo tee /etc/modprobe.d/nvidia.conf <<EOF > /dev/null
options nvidia_drm modeset=1
EOF

  # Configure initramfs for early loading (Ubuntu uses update-initramfs, not mkinitcpio)
  if [[ ! -f /etc/initramfs-tools/modules ]]; then
    sudo touch /etc/initramfs-tools/modules
  fi
  for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    grep -qxF "$mod" /etc/initramfs-tools/modules || echo "$mod" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
  done
  sudo update-initramfs -u

  # Add NVIDIA environment variables based on GPU architecture
  if [[ $GPU_ARCH = "turing_plus" ]]; then
    # Turing+ (RTX 20xx, GTX 16xx, and newer) with GSP firmware support
    cat >>"$HOME/.config/hypr/envs.lua" <<'EOF'

-- NVIDIA (Turing+ with GSP firmware)
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
EOF
  elif [[ $GPU_ARCH = "maxwell_pascal_volta" ]]; then
    # Maxwell/Pascal/Volta — lack GSP firmware
    cat >>"$HOME/.config/hypr/envs.lua" <<'EOF'

-- NVIDIA (Maxwell/Pascal/Volta without GSP firmware)
hl.env("NVD_BACKEND", "egl")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
EOF
  fi
fi

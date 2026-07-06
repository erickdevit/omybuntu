echo "Enable FRED on Intel Panther Lake systems"

DEFAULT_LIMINE="/etc/default/limine"

if omybuntu-hw-intel-ptl && [[ -f $DEFAULT_LIMINE ]] && ! grep -q 'fred=on' "$DEFAULT_LIMINE"; then
  source "$OMYBUNTU_PATH/install/config/hardware/intel/fred.sh"

  if omybuntu-cmd-present limine-update; then
    sudo limine-update
  fi
fi

echo "Fix disable-while-typing on ASUS ROG Flow Z13 detachable keyboard"

source $OMYBUNTU_PATH/install/config/hardware/asus/fix-z13-touchpad.sh

if [[ -f /etc/udev/rules.d/99-omybuntu-asus-z13-touchpad.rules ]]; then
  omybuntu-state set reboot-required
fi

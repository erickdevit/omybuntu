echo "Install swayOSD to show volume status"

if omybuntu-cmd-missing swayosd-server; then
  omybuntu-pkg-add swayosd
  setsid uwsm-app -- swayosd-server &>/dev/null &
fi

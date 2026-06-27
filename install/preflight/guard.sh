abort() {
  echo -e "\e[31mOmybuntu install requires: $1\e[0m"
  echo
  gum confirm "Proceed anyway on your own accord and without assistance?" || exit 1
}

# Must be Ubuntu
if [[ ! -f /etc/os-release ]] || ! grep -qi "ubuntu" /etc/os-release; then
  abort "Ubuntu"
fi

# Must not be running as root (unless in ISO/chroot build)
if (( EUID == 0 )) && [[ -z ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
  abort "Running as root (not user)"
fi

# Must be x86_64
if [[ $(uname -m) != "x86_64" ]]; then
  abort "x86_64 CPU"
fi

# Cleared all guards
echo "Guards: OK"

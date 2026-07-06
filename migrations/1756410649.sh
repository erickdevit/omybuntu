echo "Remove any Chaotic-AUR infrastructure packages"

omybuntu-pkg-drop chaotic-keyring chaotic-mirrorlist

if command -v pacman-key &>/dev/null; then
  if sudo pacman-key --list-keys 3056513887B78AEB >/dev/null 2>&1; then
    sudo pacman-key --delete 3056513887B78AEB
  fi
fi

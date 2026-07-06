echo "Migrate AUR packages to official repos where possible"

reinstall_package_opr() {
  if omybuntu-pkg-present $1; then
    omybuntu-pkg-drop $1 || true
    omybuntu-pkg-add ${2:-$1} || true
  fi
}

omybuntu-pkg-drop yay-bin-debug

reinstall_package_opr yay-bin yay
reinstall_package_opr obsidian-bin obsidian
reinstall_package_opr localsend-bin localsend
reinstall_package_opr omybuntu-chromium-bin omybuntu-chromium
reinstall_package_opr python-terminaltexteffects
reinstall_package_opr tzupdate
reinstall_package_opr typora
reinstall_package_opr ttf-ia-writer

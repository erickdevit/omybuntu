echo "Switch back to mainline chromium now that it supports full live theming"

if omybuntu-pkg-present omybuntu-chromium; then
  if gum confirm "Ready to switch to mainstream chromium? (Will close Chromium + reset settings)"; then
    pkill -x chromium
    omybuntu-pkg-drop omybuntu-chromium
    omybuntu-pkg-add chromium
    omybuntu-theme-set-browser
  fi
fi

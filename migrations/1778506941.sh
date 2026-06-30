echo "Install quickshell for the image selector"

if omybuntu-cmd-missing quickshell; then
  bash "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/install/build-quickshell.sh"
fi

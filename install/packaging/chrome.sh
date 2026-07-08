echo "Installing Google Chrome..."

copy_chromium_flags() {
  mkdir -p ~/.config
  cp -f "$OMYBUNTU_PATH/config/chromium-flags.conf" ~/.config/chrome-flags.conf
}

patch_chrome_desktop_file() {
  local desktop_name="$1"
  local flags
  local src_desktop="/usr/share/applications/$desktop_name"
  local dest_desktop="$HOME/.local/share/applications/$desktop_name"

  [[ -f $src_desktop ]] || return 0

  mkdir -p "$HOME/.local/share/applications"
  cp -f "$src_desktop" "$dest_desktop"

  flags=$(grep -v '^[[:space:]]*#' ~/.config/chrome-flags.conf | grep -v '^[[:space:]]*$' | sed "s|~|$HOME|g" | xargs)
  if [[ -n $flags ]]; then
    sed -i -E "s|^(Exec=[^ ]+)(.*)|\1 $flags\2|" "$dest_desktop"
  fi
}

# Download and install Google Chrome Stable
wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/google-chrome-stable_current_amd64.deb

# Setup chrome policies directory and copy chromium flags
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo chmod a+rw /etc/opt/chrome/policies/managed
copy_chromium_flags
patch_chrome_desktop_file google-chrome.desktop
patch_chrome_desktop_file com.google.Chrome.desktop

echo "Google Chrome installed successfully."

echo "Installing Google Chrome..."

# Download and install Google Chrome Stable
wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/google-chrome-stable_current_amd64.deb

# Setup chrome policies directory and copy chromium flags
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo chmod a+rw /etc/opt/chrome/policies/managed
mkdir -p ~/.config
cp -f "$OMYBUNTU_PATH/config/chromium-flags.conf" ~/.config/chrome-flags.conf

echo "Google Chrome installed successfully."

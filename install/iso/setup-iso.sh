echo "Preparing Omybuntu Live ISO Environment..."

# Create the autostart directory for skel (so the live user gets it)
sudo mkdir -p /etc/skel/.config/autostart
cat <<EOF | sudo tee /etc/skel/.config/autostart/omybuntu-installer.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=Install Omybuntu
Exec=foot -F -e omybuntu-setup-install
Icon=system-software-install
Categories=System;
Terminal=false
EOF

# Ensure live autologin is configured for the 'ubuntu' user (Casper standard)
sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
[Autologin]
User=ubuntu
Session=omybuntu

[Theme]
Current=omybuntu
EOF

echo "Live ISO environment prepared successfully with TUI Installer."

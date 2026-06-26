echo "Preparing Omybuntu Live ISO Environment..."

# Install Calamares and dependencies
omybuntu-pkg-add calamares

# Copy custom Calamares settings
sudo mkdir -p /etc/calamares
sudo cp -rf "$OMYBUNTU_PATH/install/iso/calamares/"* /etc/calamares/

# Create the autostart directory for skel (so the live user gets it)
sudo mkdir -p /etc/skel/.config/autostart
cat <<EOF | sudo tee /etc/skel/.config/autostart/calamares.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=Install Omybuntu
Exec=sudo -E calamares
Icon=calamares
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

# Make sure scripts and configuration modules have proper permissions
sudo chmod +x /etc/calamares/scripts/language-fallback.sh || true

echo "Live ISO environment prepared successfully."

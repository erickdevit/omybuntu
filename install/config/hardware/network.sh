# Ensure iwd and NetworkManager services will be started
sudo systemctl enable iwd.service
sudo systemctl enable NetworkManager.service

# Configure Netplan to use NetworkManager for all interfaces
sudo mkdir -p /etc/netplan
cat <<EOF | sudo tee /etc/netplan/01-network-manager-all.yaml >/dev/null
network:
  version: 2
  renderer: NetworkManager
EOF

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service


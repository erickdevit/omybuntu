# Install Omybuntu GRUB theme
# Generates theme assets and configures GRUB to use them

if ! command -v update-grub >/dev/null 2>&1; then
  echo "update-grub not found; GRUB may not be installed yet. Skipping theme installation." >&2
  return 0 2>/dev/null || exit 0
fi

echo "Configuring Omybuntu GRUB theme..."

# Generate theme assets
source "$OMYBUNTU_INSTALL/packaging/grub-theme.sh"

# Copy default GRUB config
sudo cp "$OMYBUNTU_PATH/default/grub/config" /etc/default/grub

# Update GRUB to apply theme
sudo update-grub

echo "Omybuntu GRUB theme configured successfully."

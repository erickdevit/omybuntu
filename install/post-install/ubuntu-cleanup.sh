# Read decision from state file
REMOVE_DESKTOP="false"
if [[ -f "$HOME/.config/omybuntu/remove_ubuntu_desktop" ]]; then
  REMOVE_DESKTOP=$(cat "$HOME/.config/omybuntu/remove_ubuntu_desktop")
fi

if [[ $REMOVE_DESKTOP != "true" ]]; then
  echo "Skipping removal of default Ubuntu GNOME Desktop Environment."
  return 0 2>/dev/null || exit 0
fi

echo "Cleaning up default Ubuntu desktop environment..."

# List of packages to remove
packages_to_remove=(
  "ubuntu-desktop"
  "ubuntu-desktop-minimal"
  "gnome-shell"
  "gdm3"
  "gnome-control-center"
  "update-manager"
  "update-notifier"
  "gnome-software"
  "gnome-session"
  "gnome-shell-extension-ubuntu-dock"
  "gnome-shell-extension-appindicator"
  "gnome-shell-extension-desktop-icons-ng"
  "yelp"
)

# Use omybuntu-pkg-drop to safely remove them
for pkg in "${packages_to_remove[@]}"; do
  omybuntu-pkg-drop "$pkg"
done

# Run autoremove to clean up orphaned dependencies 
# EXCEPT the ones we explicitly want to keep, which we mark as manually installed just in case.
sudo apt-mark manual nautilus baobab ubuntu-advantage-tools snapd fwupd gnome-firmware || true

echo "Removing orphaned packages..."
sudo apt-get autoremove -y --purge

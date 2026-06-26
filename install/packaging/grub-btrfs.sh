echo "Compiling and installing grub-btrfs..."

# Install dependencies if not present
omybuntu-pkg-add make git inotify-tools

# Clone and install
rm -rf /tmp/grub-btrfs
git clone https://github.com/Antynea/grub-btrfs.git /tmp/grub-btrfs
pushd /tmp/grub-btrfs >/dev/null
sudo make install
popd >/dev/null
rm -rf /tmp/grub-btrfs

echo "grub-btrfs installed successfully."

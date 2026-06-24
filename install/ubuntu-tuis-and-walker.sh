#!/bin/bash
set -e
echo "Installing Walker, Elephant, and TUI apps..."

mkdir -p ~/.local/bin

echo "Downloading Walker..."
curl -sL https://github.com/abenz1267/walker/releases/download/v2.16.2/walker-v2.16.2-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C ~/.local/bin/

echo "Downloading Elephant..."
curl -sL https://github.com/abenz1267/elephant/releases/download/v2.21.0/elephant-linux-amd64.tar.gz | tar -xzf - -O > ~/.local/bin/elephant
chmod +x ~/.local/bin/elephant

echo "Downloading Elephant plugins..."
sudo mkdir -p /usr/lib/elephant/providers
for plugin in desktopapplications calc files symbols websearch clipboard menus windows; do
  echo "  - $plugin"
  curl -sL "https://github.com/abenz1267/elephant/releases/download/v2.21.0/${plugin}-linux-amd64.tar.gz" | sudo tar -xz -C /usr/lib/elephant/providers/
done

# Fix naming of plugins
for f in /usr/lib/elephant/providers/*-linux-amd64.so; do
  sudo mv "$f" "${f%-linux-amd64.so}.so" 2>/dev/null || true
done

echo "Downloading Impala..."
curl -sL https://github.com/pythops/impala/releases/download/v0.7.4/impala-x86_64-unknown-linux-musl -o ~/.local/bin/impala
chmod +x ~/.local/bin/impala

echo "Downloading Bluetuith..."
curl -sL https://github.com/bluetuith-org/bluetuith/releases/download/v0.2.6/bluetuith_0.2.6_Linux_x86_64.tar.gz | tar -xz -C ~/.local/bin/ bluetuith

echo "Downloading Wiremix..."
curl -sL https://archlinux.org/packages/extra/x86_64/wiremix/download/ -o /tmp/wiremix.pkg.tar.zst
tar --zstd -xf /tmp/wiremix.pkg.tar.zst usr/bin/wiremix -O > ~/.local/bin/wiremix
chmod +x ~/.local/bin/wiremix
rm -f /tmp/wiremix.pkg.tar.zst

echo "Done!"

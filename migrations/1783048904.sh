echo "Install hyprsunset blue light filter"

if omybuntu-cmd-missing hyprsunset; then
  mkdir -p "$HOME/.local/bin"
  curl -sL https://archive.archlinux.org/packages/h/hyprsunset/hyprsunset-0.3.3-5-x86_64.pkg.tar.zst -o /tmp/hyprsunset.pkg.tar.zst
  tar --zstd -xf /tmp/hyprsunset.pkg.tar.zst usr/bin/hyprsunset -O > "$HOME/.local/bin/hyprsunset"
  chmod +x "$HOME/.local/bin/hyprsunset"
  rm -f /tmp/hyprsunset.pkg.tar.zst
fi

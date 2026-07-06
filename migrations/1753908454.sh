echo "Migrate from manually downloaded fonts to font packages"
if ! omybuntu-pkg-present ttf-cascadia-mono-nerd &>/dev/null; then
  omybuntu-pkg-add ttf-cascadia-mono-nerd || true
  rm -rf ~/.local/share/fonts/Caskaydia*
  fc-cache
fi

if ! omybuntu-pkg-present ttf-ia-writer &>/dev/null; then
  omybuntu-pkg-add ttf-ia-writer || true
  rm -rf ~/.local/share/fonts/iAWriterMonoS*
  fc-cache
fi

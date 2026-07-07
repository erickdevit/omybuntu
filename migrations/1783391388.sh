echo "Regenerate GRUB theme text for the configured Omybuntu language"

if ! omybuntu-cmd-present omybuntu-refresh-grub; then
  return 0
fi

if [[ ! -f ~/.config/omybuntu/language ]]; then
  return 0
fi

omybuntu-refresh-grub
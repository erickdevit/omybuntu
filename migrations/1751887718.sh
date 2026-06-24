echo "Install Impala as new wifi selection TUI"

if omybuntu-cmd-missing impala; then
  omybuntu-pkg-add impala
  omybuntu-refresh-waybar
fi

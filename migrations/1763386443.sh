echo "Uniquely identify terminal apps with custom app-ids using omybuntu-launch-tui"

# Replace terminal -e calls with omybuntu-launch-tui in bindings
sed -i 's/\$terminal -e \([^ ]*\)/omybuntu-launch-tui \1/g' ~/.config/hypr/bindings.conf

# Update waybar to use omybuntu-launch-or-focus with omybuntu-launch-tui for TUI apps
sed -i 's|xdg-terminal-exec btop|omybuntu-launch-or-focus-tui btop|' ~/.config/waybar/config.jsonc
sed -i 's|xdg-terminal-exec --app-id=com\.omybuntu\.Wiremix -e wiremix|omybuntu-launch-or-focus-tui wiremix|' ~/.config/waybar/config.jsonc

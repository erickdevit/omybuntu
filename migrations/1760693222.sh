echo "Use explicit timezone selector when right-clicking on clock"

sed -i 's/omybuntu-cmd-tzupdate/omybuntu-launch-floating-terminal-with-presentation omybuntu-tz-select/g' ~/.config/waybar/config.jsonc

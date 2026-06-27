#!/bin/bash

# Ensure Walker service is started automatically on boot
mkdir -p ~/.config/autostart/
cp $OMYBUNTU_PATH/default/walker/walker.desktop ~/.config/autostart/

# And is restarted if it crashes or is killed
mkdir -p ~/.config/systemd/user/app-walker@autostart.service.d/
cp $OMYBUNTU_PATH/default/walker/restart.conf ~/.config/systemd/user/app-walker@autostart.service.d/restart.conf

# Create pacman hook to restart walker after updates (Arch only)
if command -v pacman >/dev/null 2>&1; then
  sudo mkdir -p /etc/pacman.d/hooks
  sudo tee /etc/pacman.d/hooks/walker-restart.hook > /dev/null << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = walker
Target = walker-debug
Target = elephant*

[Action]
Description = Restarting Walker services after system update
When = PostTransaction
Exec = $OMYBUNTU_PATH/bin/omybuntu-restart-walker
EOF
fi

# Link the visual theme menu config
mkdir -p ~/.config/elephant/menus
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_themes.lua ~/.config/elephant/menus/omybuntu_themes.lua
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_background_selector.lua ~/.config/elephant/menus/omybuntu_background_selector.lua
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_unlocks.lua ~/.config/elephant/menus/omybuntu_unlocks.lua

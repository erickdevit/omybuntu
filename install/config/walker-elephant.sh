#!/bin/bash

# Ensure Walker service is started automatically on boot
mkdir -p ~/.config/autostart/
cp $OMYBUNTU_PATH/default/walker/walker.desktop ~/.config/autostart/

# And is restarted if it crashes or is killed
mkdir -p ~/.config/systemd/user/app-walker@autostart.service.d/
cp $OMYBUNTU_PATH/default/walker/restart.conf ~/.config/systemd/user/app-walker@autostart.service.d/restart.conf

# Create apt hook to restart walker after updates (Ubuntu only)
if command -v apt-get >/dev/null 2>&1; then
  sudo mkdir -p /etc/apt/apt.conf.d
  sudo tee /etc/apt/apt.conf.d/99walker-restart > /dev/null << 'EOF'
DPkg::Post-Invoke {"( [ -f /usr/bin/walker ] && [ \"\$(( \$(date +%s) - \$(stat -c %Y /usr/bin/walker 2>/dev/null || echo 0) ))\" -lt 120 ] || [ -f /usr/bin/elephant ] && [ \"\$(( \$(date +%s) - \$(stat -c %Y /usr/bin/elephant 2>/dev/null || echo 0) ))\" -lt 120 ] ) && /opt/omybuntu/bin/omybuntu-restart-walker || true";};
EOF
fi

# Link the visual theme menu config
mkdir -p ~/.config/elephant/menus
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_themes.lua ~/.config/elephant/menus/omybuntu_themes.lua
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_background_selector.lua ~/.config/elephant/menus/omybuntu_background_selector.lua
ln -snf $OMYBUNTU_PATH/default/elephant/omybuntu_unlocks.lua ~/.config/elephant/menus/omybuntu_unlocks.lua

echo "Update polkit autostart paths and browser launchers for keyring support"

# 1. Update active autostart configs to use Ubuntu policykit path
if [[ -f ~/.config/hypr/autostart.conf ]]; then
  sed -i 's|/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1|/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1|g' ~/.config/hypr/autostart.conf
fi
if [[ -f ~/.config/hypr/autostart.lua ]]; then
  sed -i 's|/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1|/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1|g' ~/.config/hypr/autostart.lua
fi

# 2. Ensure default chromium-flags has password store in ~/.config
if [[ -f ~/.config/chromium-flags.conf ]]; then
  if ! grep -q "password-store=gnome-libsecret" ~/.config/chromium-flags.conf; then
    echo "--password-store=gnome-libsecret" >> ~/.config/chromium-flags.conf
  fi
else
  mkdir -p ~/.config
  cp -f "$OMYBUNTU_PATH/config/chromium-flags.conf" ~/.config/chromium-flags.conf
fi

# 3. Ensure other browser specific flags exist
for browser in chrome brave microsoft-edge-stable; do
  if [[ ! -f ~/.config/${browser}-flags.conf ]]; then
    cp -f ~/.config/chromium-flags.conf ~/.config/${browser}-flags.conf 2>/dev/null || true
  fi
done

# 4. Patch existing desktop files for installed browsers to respect the flags
patch_desktop_file() {
  local desktop_name="$1"
  local flags_file="$2"
  
  local src_desktop="/usr/share/applications/$desktop_name"
  local dest_desktop="$HOME/.local/share/applications/$desktop_name"
  
  if [[ -f $src_desktop ]]; then
    mkdir -p "$HOME/.local/share/applications"
    cp -f "$src_desktop" "$dest_desktop"
    
    if [[ -f $flags_file ]]; then
      local flags
      flags=$(grep -v '^\s*#' "$flags_file" | grep -v '^\s*$' | sed "s|~|$HOME|g" | xargs)
      if [[ -n $flags ]]; then
        sed -i -E "s|^(Exec=[^ ]+)(.*)|\1 $flags\2|" "$dest_desktop"
      fi
    fi
  fi
}

patch_desktop_file google-chrome.desktop ~/.config/chrome-flags.conf
patch_desktop_file brave-browser.desktop ~/.config/brave-flags.conf
patch_desktop_file microsoft-edge.desktop ~/.config/microsoft-edge-stable-flags.conf
patch_desktop_file brave-browser-beta.desktop ~/.config/brave-origin-beta-flags.conf

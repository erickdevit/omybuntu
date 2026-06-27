# Set links for Nautilus action icons
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg

# Setup user theme folder
mkdir -p ~/.config/omybuntu/themes

# Chromium policy directory for theme
sudo mkdir -p /etc/chromium/policies/managed
sudo chmod a+rw /etc/chromium/policies/managed

# Set initial theme
omybuntu-theme-set "Omybuntu"
rm -rf ~/.config/chromium/SingletonLock ~/.config/google-chrome/SingletonLock

# Set specific app links for current theme
mkdir -p ~/.config/btop/themes
ln -snf ~/.config/omybuntu/current/theme/btop.theme ~/.config/btop/themes/current.theme

mkdir -p ~/.config/mako
ln -snf ~/.config/omybuntu/current/theme/mako.ini ~/.config/mako/config

mkdir -p ~/.config/cava
ln -snf ~/.config/omybuntu/current/theme/cava.ini ~/.config/cava/config

# Default Chromium to follow system appearance ("device") instead of dark
sudo mkdir -p /usr/lib/chromium
echo '{"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' | sudo tee /usr/lib/chromium/initial_preferences >/dev/null

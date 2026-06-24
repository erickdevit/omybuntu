echo "Add UWSM env"

export OMYBUNTU_PATH="$HOME/.local/share/omybuntu"
export PATH="$OMYBUNTU_PATH/bin:$PATH"

mkdir -p "$HOME/.config/uwsm/"
cat <<EOF | tee "$HOME/.config/uwsm/env"
export OMYBUNTU_PATH=$HOME/.local/share/omybuntu
export PATH=$OMYBUNTU_PATH/bin/:$PATH
EOF

# Ensure we have the latest repos and are ready to pull
omybuntu-update-keyring
omybuntu-refresh-pacman
sudo systemctl restart systemd-timesyncd
sudo pacman -Sy # Normally not advisable, but we'll do a full -Syu before finishing

mkdir -p ~/.local/state/omybuntu/migrations
touch ~/.local/state/omybuntu/migrations/1751134560.sh

# Remove old AUR packages to prevent a super lengthy build on old Omybuntu installs
omybuntu-pkg-drop zoom qt5-remoteobjects wf-recorder wl-screenrec

# Get rid of old AUR packages
bash $OMYBUNTU_PATH/migrations/1756060611.sh
touch ~/.local/state/omybuntu/migrations/1756060611.sh

bash omybuntu-update-perform

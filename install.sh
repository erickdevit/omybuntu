#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Omybuntu locations
export OMYBUNTU_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OMYBUNTU_INSTALL="$OMYBUNTU_PATH/install"
export OMYBUNTU_INSTALL_LOG_FILE="/var/log/omybuntu-install.log"
export PATH="$OMYBUNTU_PATH/bin:$PATH"

# Sourced helpers (loads gum and logo functions)
source "$OMYBUNTU_INSTALL/helpers/all.sh"

# Select language
clear_logo
echo -e "\nChoose Omybuntu language / Selecione o idioma / Seleccione el idioma:"
CHOSEN_LANG=$(gum choose --height 5 "English" "Português (Brasil)" "Español")

case "$CHOSEN_LANG" in
  "Português (Brasil)") LANG_VAL="pt-br" ;;
  "Español") LANG_VAL="es" ;;
  *) LANG_VAL="en" ;;
esac

mkdir -p "$HOME/.config/omybuntu"
echo "$LANG_VAL" > "$HOME/.config/omybuntu/language"
export OMYBUNTU_LANGUAGE="$LANG_VAL"

# Load translation variables
source "$OMYBUNTU_PATH/default/i18n/init.sh"

# Determine if we should remove Ubuntu Desktop (GNOME/GDM3)
mkdir -p "$HOME/.config/omybuntu"
if [[ -n ${OMYBUNTU_ISO_BUILD:-} || -n ${OMYBUNTU_CHROOT_INSTALL:-} ]]; then
  # On ISO builds (starts from a clean rootfs), we don't have GNOME to remove
  echo "false" > "$HOME/.config/omybuntu/remove_ubuntu_desktop"
else
  if gum confirm "$I18N_REMOVE_GNOME_PROMPT" --default=false; then
    echo "true" > "$HOME/.config/omybuntu/remove_ubuntu_desktop"
  else
    echo "false" > "$HOME/.config/omybuntu/remove_ubuntu_desktop"
  fi
fi

# Install
source "$OMYBUNTU_INSTALL/preflight/all.sh"
source "$OMYBUNTU_INSTALL/packaging/all.sh"
source "$OMYBUNTU_INSTALL/config/all.sh"
source "$OMYBUNTU_INSTALL/login/all.sh"
source "$OMYBUNTU_INSTALL/post-install/all.sh"

#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Omybuntu locations
export OMYBUNTU_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OMYBUNTU_INSTALL="$OMYBUNTU_PATH/install"
export OMYBUNTU_INSTALL_LOG_FILE="/var/log/omybuntu-install.log"
export PATH="$OMYBUNTU_PATH/bin:$PATH"

# Install
source "$OMYBUNTU_INSTALL/helpers/all.sh"
source "$OMYBUNTU_INSTALL/preflight/all.sh"
source "$OMYBUNTU_INSTALL/packaging/all.sh"
source "$OMYBUNTU_INSTALL/config/all.sh"
source "$OMYBUNTU_INSTALL/login/all.sh"
source "$OMYBUNTU_INSTALL/post-install/all.sh"

#!/bin/bash

# Set install mode to online since boot.sh is used for curl installations
export OMYBUNTU_ONLINE_INSTALL=true

ansi_art='                 ▄▄▄
 ▄█████▄    ▄███████████▄    ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███
███   ███  ███   ███   ███ ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███
███   ███  ███   ███   ███ ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███
███   ███  ███   ███   ███  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
 ▀█████▀    ▀█   ███   █▀   ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀
                                       ███   █▀                                  '

clear
echo -e "\n$ansi_art\n"

# Use custom branch if instructed, otherwise default to master
OMYBUNTU_REF="${OMYBUNTU_REF:-master}"

# No custom mirrors needed for Ubuntu currently
if [[ $OMYBUNTU_REF == "dev" ]]; then
  echo -e "\e[33mDev branch selected\e[0m"
elif [[ $OMYBUNTU_REF == "rc" ]]; then
  echo -e "\e[33mRC branch selected\e[0m"
else
  echo -e "\e[32mStable branch selected\e[0m"
fi

sudo apt-get update && sudo apt-get install -y git curl sudo

# Use custom repo if specified, otherwise default to basecamp/omybuntu
OMYBUNTU_REPO="${OMYBUNTU_REPO:-basecamp/omybuntu}"

echo -e "\nCloning Omybuntu from: https://github.com/${OMYBUNTU_REPO}.git"
rm -rf ~/.local/share/omybuntu/
git clone "https://github.com/${OMYBUNTU_REPO}.git" ~/.local/share/omybuntu >/dev/null

echo -e "\e[32mUsing branch: $OMYBUNTU_REF\e[0m"
cd ~/.local/share/omybuntu
git fetch origin "${OMYBUNTU_REF}" && git checkout "${OMYBUNTU_REF}"
cd -

echo -e "\nInstallation starting..."
source ~/.local/share/omybuntu/install.sh

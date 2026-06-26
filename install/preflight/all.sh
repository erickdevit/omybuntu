# Must be Ubuntu
if [[ ! -f /etc/os-release ]] || ! grep -qi "ubuntu" /etc/os-release; then
  printf "\e[31m$(printf "$I18N_ERR_INSTALL_REQ" "Ubuntu")\e[0m\n\n"
  gum confirm "$I18N_PROCEED_ANYWAY" || exit 1
fi

if [[ -n ${OMYBUNTU_ONLINE_INSTALL:-} ]]; then
  sudo add-apt-repository universe -y

  # Add official mise repository
  sudo install -dm 755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list

  sudo apt-get update
fi

source $OMYBUNTU_INSTALL/preflight/begin.sh
run_logged $OMYBUNTU_INSTALL/preflight/show-env.sh
run_logged $OMYBUNTU_INSTALL/preflight/migrations.sh
run_logged $OMYBUNTU_INSTALL/preflight/first-run-mode.sh

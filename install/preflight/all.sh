# Must be Ubuntu
if [[ ! -f /etc/os-release ]] || ! grep -qi "ubuntu" /etc/os-release; then
  printf "\e[31m$(printf "$I18N_ERR_INSTALL_REQ" "Ubuntu")\e[0m\n\n"
  gum confirm "$I18N_PROCEED_ANYWAY" || exit 1
fi

source $OMYBUNTU_INSTALL/preflight/begin.sh

if [[ -n ${OMYBUNTU_ONLINE_INSTALL:-} ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: online preflight" >> "$OMYBUNTU_INSTALL_LOG_FILE"

  {
    sudo add-apt-repository universe -y

    # Add official mise repository
    sudo install -dm 755 /etc/apt/keyrings
    curl --connect-timeout 15 --max-time 120 -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/mise.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list

    sudo apt-get \
      -o Acquire::http::Timeout=30 \
      -o Acquire::https::Timeout=30 \
      -o DPkg::Lock::Timeout=60 \
      update
  } >> "$OMYBUNTU_INSTALL_LOG_FILE" 2>&1

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: online preflight" >> "$OMYBUNTU_INSTALL_LOG_FILE"
fi

run_logged $OMYBUNTU_INSTALL/preflight/show-env.sh
run_logged $OMYBUNTU_INSTALL/preflight/migrations.sh
run_logged $OMYBUNTU_INSTALL/preflight/first-run-mode.sh

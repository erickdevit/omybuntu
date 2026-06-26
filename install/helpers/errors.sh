# Directs user to Omybuntu Discord
QR_CODE='
█▀▀▀▀▀█  ▀▀█▄██ ▄ █▀▀▀▀▀█
█ ███ █ ▄▀██▄▄█ █ █ ███ █
█ ▀▀▀ █ ▀▄█ ▀█▄ ▀ █ ▀▀▀ █
▀▀▀▀▀▀▀ ▀▄▀ █ █▄█ ▀▀▀▀▀▀▀
█▀▄▄▄▀▀█▄▀█▄▀ █▄▄  ▄██▄▄
▀▄▄▄▄▀▀▀ ▀▄▄▄ ▄▀▄▄▄▄ █ ▀█
▄▄ ▄ █▀█▀██▄▀▀▄██▄▀█   ▄▀
█ ▄▄▄▄▀ ▀█ ▄ ▀▀█▄▄▀█▀█▄▀█
▀ ▀▀▀▀▀▀█ ▄ ▀▀▀██▀▀▀█ ▀
█▀▀▀▀▀█ █▄▄█ ▀▄▄█ ▀ █   █
█ ███ █  ▄▀  ███▀██▀▀ ▀█▄
█ ▀▀▀ █ ▄█▀▄█▀▀ █ ▄▄▄▀▀ █
▀▀▀▀▀▀▀ ▀▀▀▀▀▀  ▀    ▀  ▀'

# Track if we're already handling an error to prevent double-trapping
ERROR_HANDLING=false

# Cursor is usually hidden while we install
show_cursor() {
  printf "\033[?25h"
}

# Display truncated log lines from the install log
show_log_tail() {
  if [[ -f $OMYBUNTU_INSTALL_LOG_FILE ]]; then
    local log_lines=$((TERM_HEIGHT - LOGO_HEIGHT - 35))
    local max_line_width=$((LOGO_WIDTH - 4))

    tail -n $log_lines "$OMYBUNTU_INSTALL_LOG_FILE" | while IFS= read -r line; do
      if ((${#line} > max_line_width)); then
        local truncated_line="${line:0:$max_line_width}..."
      else
        local truncated_line="$line"
      fi

      gum style "$truncated_line"
    done

    echo
  fi
}

# Display the failed command or script name
show_failed_script_or_command() {
  if [[ -n ${CURRENT_SCRIPT:-} ]]; then
    gum style "Failed script: $CURRENT_SCRIPT"
  else
    # Truncate long command lines to fit the display
    local cmd="$BASH_COMMAND"
    local max_cmd_width=$((LOGO_WIDTH - 4))

    if ((${#cmd} > max_cmd_width)); then
      cmd="${cmd:0:$max_cmd_width}..."
    fi

    gum style "$cmd"
  fi
}

# Save original stdout and stderr for trap to use
save_original_outputs() {
  exec 3>&1 4>&2
}

# Restore stdout and stderr to original (saved in FD 3 and 4)
# This ensures output goes to screen, not log file
restore_outputs() {
  if [[ -e /proc/self/fd/3 ]] && [[ -e /proc/self/fd/4 ]]; then
    exec 1>&3 2>&4
  fi
}

# Error handler
catch_errors() {
  # Capture exit code FIRST before any command modifies $?
  local exit_code=$?

  # Prevent recursive error handling
  if [[ $ERROR_HANDLING == "true" ]]; then
    return
  else
    ERROR_HANDLING=true
  fi

  # Ensure translation variables are loaded
  if [[ -z ${I18N_ERR_WHAT_TO_DO:-} ]]; then
    source "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/default/i18n/init.sh" || true
  fi

  stop_log_output
  restore_outputs

  clear_logo
  show_cursor

  gum style --foreground 1 --padding "1 0 1 $PADDING_LEFT" "Omybuntu installation stopped!"
  show_log_tail

  gum style "This command halted with exit code $exit_code:"
  show_failed_script_or_command

  gum style "$QR_CODE"
  echo
  gum style "Get help from the community via QR code or at https://discord.gg/AWenBWGka"

  # In ISO/chroot builds, exit immediately on error
  if [[ -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
    exit 1
  fi

  # Offer options menu
  while true; do
    options=()

    # If online install, show retry first
    if [[ -n ${OMYBUNTU_ONLINE_INSTALL:-} ]]; then
      options+=("$I18N_ERR_RETRY")
    fi

    # Add upload option if internet is available
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
      options+=("$I18N_ERR_UPLOAD")
    fi

    # Add remaining options
    options+=("$I18N_ERR_VIEW")
    options+=("$I18N_ERR_EXIT")

    choice=$(gum choose "${options[@]}" --header "$I18N_ERR_WHAT_TO_DO" --height 6 --padding "1 $PADDING_LEFT")

    case "$choice" in
    "$I18N_ERR_RETRY")
      bash "$OMYBUNTU_PATH"/install.sh
      break
      ;;
    "$I18N_ERR_VIEW")
      if command -v less &>/dev/null; then
        less "$OMYBUNTU_INSTALL_LOG_FILE"
      else
        tail "$OMYBUNTU_INSTALL_LOG_FILE"
      fi
      ;;
    "$I18N_ERR_UPLOAD")
      omybuntu-upload-log
      ;;
    "$I18N_ERR_EXIT" | "")
      exit 1
      ;;
    esac
  done
}

# Exit handler - ensures cleanup happens on any exit
exit_handler() {
  local exit_code=$?

  # Only run if we're exiting with an error and haven't already handled it
  if (( exit_code != 0 )) && [[ $ERROR_HANDLING != "true" ]]; then
    catch_errors
  else
    stop_log_output
    show_cursor
  fi
}

# Set up traps
trap catch_errors ERR INT TERM
trap exit_handler EXIT

# Save original outputs in case we trap
save_original_outputs

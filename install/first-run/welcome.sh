source "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/default/i18n/init.sh"

omybuntu-notification-send -g "" "$I18N_FIRST_RUN_WELCOME_TITLE" "$I18N_FIRST_RUN_WELCOME_BODY" -u critical

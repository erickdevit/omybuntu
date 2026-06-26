source "${OMYBUNTU_PATH:-$HOME/.local/share/omybuntu}/default/i18n/init.sh"

if ! ping -c3 -W1 1.1.1.1 >/dev/null 2>&1; then
  omybuntu-notification-send -g "" "$I18N_FIRST_RUN_UPDATE_TITLE" "$I18N_FIRST_RUN_UPDATE_BODY_NO_NET" -u critical
  omybuntu-notification-send -g "󰖩" "$I18N_FIRST_RUN_WIFI_TITLE" "$I18N_FIRST_RUN_WIFI_BODY" -u critical
else
  omybuntu-notification-send -g "" "$I18N_FIRST_RUN_UPDATE_TITLE" "$I18N_FIRST_RUN_UPDATE_BODY_WITH_NET" -u critical
fi

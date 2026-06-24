# Overwrite parts of the omybuntu-menu with user-specific submenus.
# See $OMYBUNTU_PATH/bin/omybuntu-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Omybuntu changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) omybuntu-system-lock ;;
#   *Shutdown*) omybuntu-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
# show_about() {
#   exec omybuntu-launch-or-focus-tui "zsh -c 'fastfetch; read -k 1'"
# }

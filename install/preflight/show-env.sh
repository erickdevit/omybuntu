# Show installation environment variables
gum log --level info "Installation Environment:"

env | grep -E "^(OMYBUNTU_CHROOT_INSTALL|OMYBUNTU_ONLINE_INSTALL|OMYBUNTU_USER_NAME|OMYBUNTU_USER_EMAIL|USER|HOME|OMYBUNTU_REPO|OMYBUNTU_REF|OMYBUNTU_PATH)=" | sort | while IFS= read -r var; do
  gum log --level info "  $var"
done

# Install all base packages
mapfile -t packages < <(grep -v '^#' "$OMYBUNTU_INSTALL/omybuntu-base.packages" | grep -v '^$')
omybuntu-pkg-add "${packages[@]}"

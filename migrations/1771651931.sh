echo "Hide wiremix and limine-snapper-restore from app launcher"

if [[ -f $OMYBUNTU_PATH/applications/hidden/wiremix.desktop ]]; then
  cp $OMYBUNTU_PATH/applications/hidden/wiremix.desktop ~/.local/share/applications/
fi
if [[ -f $OMYBUNTU_PATH/applications/hidden/limine-snapper-restore.desktop ]]; then
  cp $OMYBUNTU_PATH/applications/hidden/limine-snapper-restore.desktop ~/.local/share/applications/
fi

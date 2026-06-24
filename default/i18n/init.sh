#!/bin/bash

# Detect language configuration
LANG_FILE="$HOME/.config/omybuntu/language"
LANG_VAL="${OMYBUNTU_LANGUAGE:-}"

if [[ -z $LANG_VAL ]]; then
  if [[ -f "$LANG_FILE" ]]; then
    LANG_VAL=$(cat "$LANG_FILE")
  else
    LANG_VAL="en"
  fi
fi

# Locate the translation directory (resolve symlink to real path if necessary)
I18N_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the selected language file or fallback to English
if [[ -f "$I18N_DIR/$LANG_VAL.sh" ]]; then
  source "$I18N_DIR/$LANG_VAL.sh"
else
  source "$I18N_DIR/en.sh"
fi

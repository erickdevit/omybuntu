#!/bin/bash
# Omybuntu post-install language fallback configuration

set -e

# 1. Read locale from target system /etc/default/locale
TARGET_LANG=$(grep "^LANG=" /etc/default/locale | cut -d'=' -f2 | tr -d '"')

# 2. Check if the target language is Portuguese or Spanish
case "$TARGET_LANG" in
  pt_*|es_*)
    # Keep it! Map to corresponding omybuntu language val
    if [[ $TARGET_LANG == pt_* ]]; then
      LANG_VAL="pt-br"
    else
      LANG_VAL="es"
    fi
    ;;
  *)
    # Fallback to English
    echo "Forcing English fallback..."
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale
    echo 'LANGUAGE="en_US:en"' >> /etc/default/locale
    LANG_VAL="en"
    ;;
esac

# 3. Apply to target users (any user folder created in /home)
for user_dir in /home/*; do
  if [[ -d $user_dir ]]; then
    mkdir -p "$user_dir/.config/omybuntu"
    echo "$LANG_VAL" > "$user_dir/.config/omybuntu/language"
    # Ensure correct ownership
    username=$(basename "$user_dir")
    chown -R "$username:$username" "$user_dir/.config/omybuntu"
  fi
done

# Also apply to /etc/skel so new users get it
mkdir -p /etc/skel/.config/omybuntu
echo "$LANG_VAL" > /etc/skel/.config/omybuntu/language

# 4. Generate grub-btrfs hook on target system if it exists
if command -v grub-mkconfig >/dev/null 2>&1; then
  echo "Updating GRUB configuration on target system..."
  grub-mkconfig -o /boot/grub/grub.cfg || true
fi

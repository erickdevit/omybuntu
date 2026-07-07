# Generate GRUB theme visual assets for Omybuntu
# Uses ImageMagick to create select indicators and scrollbar thumb

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick (magick) is not installed. Skipping GRUB theme generation." >&2
  return 0 2>/dev/null || exit 0
fi

omybuntu_grub_theme_language() {
  if [[ -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
    echo "en"
    return
  fi

  if [[ -n ${OMYBUNTU_LANGUAGE:-} ]]; then
    echo "$OMYBUNTU_LANGUAGE"
    return
  fi

  if [[ -f $HOME/.config/omybuntu/language ]]; then
    cat "$HOME/.config/omybuntu/language"
    return
  fi

  echo "en"
}

omybuntu_render_grub_theme_txt() {
  local out_file=$1
  local lang
  lang=$(omybuntu_grub_theme_language)

  export OMYBUNTU_LANGUAGE="$lang"
  # shellcheck disable=SC1091
  source "$OMYBUNTU_PATH/default/i18n/init.sh"

  local rendered
  rendered=$(mktemp)
  sed \
    -e "s|{{ grub_select_os }}|$I18N_GRUB_SELECT_OS|g" \
    -e "s|{{ grub_footer }}|$I18N_GRUB_FOOTER|g" \
    "$OMYBUNTU_PATH/default/grub/theme.tpl" > "$rendered"

  if [[ $out_file == /boot/* || -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
    sudo tee "$out_file" < "$rendered" >/dev/null
  else
    cp "$rendered" "$out_file"
  fi
  rm -f "$rendered"
}

echo "Generating GRUB theme assets..."

THEME_DIR="$OMYBUNTU_PATH/default/grub"
OUT_DIR="${GRUB_THEME_OUT_DIR:-/boot/grub/themes/omybuntu}"

if [[ $OUT_DIR == /boot/* || -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
  sudo mkdir -p "$OUT_DIR"
  magick_write() {
    sudo magick "$@"
  }
else
  mkdir -p "$OUT_DIR"
  magick_write() {
    magick "$@"
  }
fi

# --- Background: Omybuntu default dark brown with subtle vignette ---
magick_write -size 1920x1080 \
  -define gradient:center=50%,50% \
  radial-gradient:'#2a1a10'-'#140a05' \
  "$OUT_DIR/background.png"

# --- Select indicator ---
for w in 200 400 600; do
  magick_write -size ${w}x28 xc:none \
    -channel RGBA \
    -fill 'rgba(245,158,11,0.15)' \
    -draw "roundrectangle 4,2 $((w-4)),26 14,14" \
    "$OUT_DIR/select_${w}.png"
done

# --- Scrollbar thumb ---
magick_write -size 6x30 xc:none \
  -channel RGBA \
  -fill 'rgba(92,64,51,0.6)' \
  -draw "roundrectangle 0,0 6,30 3,3" \
  "$OUT_DIR/scrollbar_thumb.png"

omybuntu_render_grub_theme_txt "$OUT_DIR/theme.txt"

if [[ -f /usr/share/grub/unicode.pf2 ]]; then
  if [[ $OUT_DIR == /boot/* || -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
    sudo cp -f /usr/share/grub/unicode.pf2 "$OUT_DIR/unicode.pf2"
  else
    cp -f /usr/share/grub/unicode.pf2 "$OUT_DIR/unicode.pf2"
  fi
elif [[ -f /boot/grub/unicode.pf2 ]]; then
  if [[ $OUT_DIR == /boot/* || -n ${OMYBUNTU_ISO_BUILD:-} ]]; then
    sudo cp -f /boot/grub/unicode.pf2 "$OUT_DIR/unicode.pf2"
  else
    cp -f /boot/grub/unicode.pf2 "$OUT_DIR/unicode.pf2"
  fi
fi

echo "GRUB theme assets generated successfully at $OUT_DIR"

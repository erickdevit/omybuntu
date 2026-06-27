# Generate GRUB theme visual assets for Omybuntu
# Uses ImageMagick to create background, select indicators, and scrollbar thumb
# All assets use the Tokyo Night color palette

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick (magick) is not installed. Skipping GRUB theme generation." >&2
  return 0 2>/dev/null || exit 0
fi

echo "Generating GRUB theme assets..."

THEME_DIR="$OMYBUNTU_PATH/default/grub"
OUT_DIR="/boot/grub/themes/omybuntu"

sudo mkdir -p "$OUT_DIR"

# --- Background: Omybuntu default dark brown with subtle vignette ---
# Solid Omybuntu background (#140a05) with a soft radial vignette effect
sudo magick -size 1920x1080 \
  -define gradient:center=50%,50% \
  radial-gradient:'#2a1a10'-'#140a05' \
  "$OUT_DIR/background.png"

# --- Select indicator: pill shape with Omybuntu amber accent at 15% opacity ---
# A subtle rounded rectangle that appears behind the selected menu item
for w in 200 400 600; do
  sudo magick -size ${w}x28 xc:none \
    -channel RGBA \
    -fill 'rgba(245,158,11,0.15)' \
    -draw "roundrectangle 4,2 $((w-4)),26 14,14" \
    "$OUT_DIR/select_${w}.png"
done

# --- Scrollbar thumb: subtle rounded bar at 60% opacity ---
sudo magick -size 6x30 xc:none \
  -channel RGBA \
  -fill 'rgba(92,64,51,0.6)' \
  -draw "roundrectangle 0,0 6,30 3,3" \
  "$OUT_DIR/scrollbar_thumb.png"

# --- Copy theme.txt ---
sudo cp "$THEME_DIR/theme.txt" "$OUT_DIR/theme.txt"

# --- Copy font (symlink to system unicode font) ---
sudo ln -sf /usr/share/grub/unicode.pf2 "$OUT_DIR/unicode.pf2" 2>/dev/null || \
  sudo cp /usr/share/grub/unicode.pf2 "$OUT_DIR/unicode.pf2" 2>/dev/null || true

echo "GRUB theme assets generated successfully at $OUT_DIR"

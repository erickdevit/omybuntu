mkdir -p ~/Downloads ~/Documents ~/Pictures ~/Videos ~/.config/gtk-3.0

xdg-user-dirs-update --set TEMPLATES "$HOME"
xdg-user-dirs-update --set PUBLICSHARE "$HOME"
xdg-user-dirs-update --set DESKTOP "$HOME"

rmdir ~/Templates ~/Public ~/Desktop 2>/dev/null || true

bookmark_file="$HOME/.config/gtk-3.0/bookmarks"
bookmark_tmp=$(mktemp)

touch "$bookmark_file"
grep -v -E "^file://$HOME/(Downloads|Documents|Projects|Pictures|Videos) " "$bookmark_file" >"$bookmark_tmp" || true

for dir in Downloads Documents Pictures Videos; do
  printf 'file://%s/%s %s\n' "$HOME" "$dir" "$dir" >>"$bookmark_tmp"
done

mv "$bookmark_tmp" "$bookmark_file"

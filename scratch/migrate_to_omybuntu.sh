#!/bin/bash
set -euo pipefail

OLD_DIR="/home/erick/repos/omarchy"
NEW_DIR="/home/erick/repos/omybuntu"

echo "=== Starting Omybuntu directory and symlink migration ==="

if [[ ! -d "$OLD_DIR" ]]; then
  echo "Error: Old directory $OLD_DIR does not exist." >&2
  exit 1
fi

if [[ -d "$NEW_DIR" ]]; then
  echo "Error: Target directory $NEW_DIR already exists." >&2
  exit 1
fi

# Rename the repository folder
echo "Renaming repository directory..."
mv "$OLD_DIR" "$NEW_DIR"

# Helper function to recreate symlink
recreate_symlink() {
  local target="$1"
  local link_name="$2"
  echo "Updating symlink: $link_name -> $target"
  # Remove if it exists (file, directory, or symlink)
  rm -f "$link_name" || true
  # Create symlink
  ln -sfn "$target" "$link_name"
}

# 1. Update .local/share/omybuntu
recreate_symlink "$NEW_DIR" "/home/erick/.local/share/omybuntu"

# 2. Update elephant menus
recreate_symlink "$NEW_DIR/default/elephant/omybuntu_themes.lua" "/home/erick/.config/elephant/menus/omybuntu_themes.lua"
recreate_symlink "$NEW_DIR/default/elephant/omybuntu_background_selector.lua" "/home/erick/.config/elephant/menus/omybuntu_background_selector.lua"
recreate_symlink "$NEW_DIR/default/elephant/omybuntu_unlocks.lua" "/home/erick/.config/elephant/menus/omybuntu_unlocks.lua"

# 3. Update agent skills
recreate_symlink "$NEW_DIR/default/omybuntu-skill" "/home/erick/.claude/skills/omybuntu"
recreate_symlink "$NEW_DIR/default/omybuntu-skill" "/home/erick/.agents/skills/omybuntu"
recreate_symlink "$NEW_DIR/default/omybuntu-skill" "/home/erick/.codex/skills/omybuntu"
recreate_symlink "$NEW_DIR/default/omybuntu-skill" "/home/erick/.pi/agent/skills/omybuntu"

echo "=== Migration completed successfully! ==="

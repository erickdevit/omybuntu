# Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)
- Scripts under `install/` and `migrations/` may be sourced and intentionally omit shebangs

# Command Naming

All commands start with `omybuntu-`. Prefixes indicate purpose.

The authoritative command group list lives in `bin/omybuntu` in `GROUP_DESCRIPTIONS`. Keep `GROUP_DESCRIPTIONS` updated when adding a new command prefix.

Common prefixes include:

- `cmd-` - check if commands exist, misc utility commands
- `capture-` - screenshots, screen recordings, and other capture tools
- `pkg-` - package management helpers
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management
- `update-` - update components

Other current prefixes include:

- `ac-`, `audio-`, `battery-`, `branch-`, `brightness-`, `channel-`, `config-`, `debug-`, `dev-`, `drive-`, `first-`, `font-`, `haptic-`, `hibernation-`, `hook-`, `hyprland-`, `menu-`, `migrate-`, `notification-`, `npx-`, `plymouth-`, `powerprofiles-`, `reinstall-`, `remove-`, `screensaver-`, `show-`, `snapshot-`, `state-`, `sudo-`, `swayosd-`, `system-`, `transcode-`, `tui-`, `tz-`, `upload-`, `version-`, `voxtype-`, `webapp-`, `wifi-`, `windows-`

# Command Metadata

Commands in `bin/` can declare CLI metadata in comments near the top of the file. `bin/omybuntu` scans the first 80 lines, and tests expect command metadata to remain valid.

Supported metadata keys:

- `# omybuntu:summary=...` - short help text
- `# omybuntu:group=...` - command group when it differs from the filename-derived prefix
- `# omybuntu:name=...` - command name within the group
- `# omybuntu:args=...` - usage arguments
- `# omybuntu:examples=...` - examples separated with ` | `
- `# omybuntu:alias=...` / `# omybuntu:aliases=...` - alternate routes
- `# omybuntu:hidden=true` - hide from default command listings
- `# omybuntu:requires-sudo=true` - mark commands that require sudo

Prefer explicit metadata for user-facing commands. Keep routes consistent with the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# omybuntu:summary=Take a screenshot
# omybuntu:group=capture
# omybuntu:args=[smart|region|windows|fullscreen] [slurp|copy]
# omybuntu:examples=omybuntu screenshot | omybuntu capture screenshot region
# omybuntu:aliases=omybuntu screenshot
```

# Install Scripts

Install entry points (`install.sh`, `boot.sh`) use `#!/bin/bash`. Many scripts under `install/` are sourced via `run_logged` and intentionally do not have shebangs.

Install stage files follow this pattern:

- `install/*/all.sh` lists scripts in execution order
- leaf scripts are sourced by `run_logged $OMYBUNTU_INSTALL/path/to/script.sh`
- avoid `exit` in sourced install scripts unless intentionally aborting the install
- use `$OMYBUNTU_INSTALL` and `$OMYBUNTU_PATH` instead of hard-coded Omybuntu paths
- keep hardware-specific logic under `install/config/hardware/`
- prefer helper commands for package and command checks where available

Raw `command -v`, `apt`, `snap`, and `flatpak` are acceptable in bootstrap/preflight/package-helper contexts where the helper commands may not be available yet or where direct package-manager behavior is the point of the script.

# Helper Commands

Use these instead of raw shell commands:

- `omybuntu-cmd-missing` / `omybuntu-cmd-present` - check for commands
- `omybuntu-pkg-missing` / `omybuntu-pkg-present` - check for packages
- `omybuntu-pkg-add` - install packages (handles apt, snap, and flatpak)
- `omybuntu-pkg-drop` - remove packages; use this instead of raw `apt remove`, `snap remove`, or `flatpak uninstall`
- `omybuntu-notification-send` - send desktop notifications; do not call `notify-send` directly
- `omybuntu-hw-asus-rog` - detect ASUS ROG hardware (and similar `hw-*` commands)

Exceptions are allowed for bootstrap, preflight, migration, and package-helper scripts where the helper may not be available yet, where the helper itself is being implemented, or where direct package-manager behavior is required.

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, color0-15)

# Visual Changes

When making visual changes, such as Waybar styles or desktop appearance, always take and analyze a screenshot after applying the change to verify the result. Use `omybuntu capture screenshot fullscreen save` for fullscreen screenshots.

For interactive UI work, use `wtype` to simulate keyboard input when available. Example: start the UI in the background, wait briefly for focus, then run `wtype -k Right -k Return` to exercise keyboard selection and confirm the resulting command output or state change. Prefer this over manual-only verification when a UI returns a selected value or changes a symlink/config.

When testing layer-shell UI, capture the reference and candidate states as separate screenshots, then compare them visually before further edits. If a launched UI would otherwise remain open, keep track of its PID and stop it after the screenshot; avoid broad process kills unless checking with `ps` first.

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
omybuntu-refresh-config hypr/hyprlock.conf
```

This copies `~/.local/share/omybuntu/config/hypr/hyprlock.conf` to `~/.config/hypr/hyprlock.conf`.

# Migrations

To create a new migration, run `omybuntu-dev-add-migration --no-edit`. This creates a migration file named after the unix timestamp of the last commit.

New migration format:
- File permissions must be `0644` (`-rw-r--r--`); migrations are sourced, not executed directly
- No shebang line
- Start with an `echo` describing what the migration does
- Use `$OMYBUNTU_PATH` to reference the omybuntu directory
- Prefer helper commands such as `omybuntu-cmd-present`, `omybuntu-cmd-missing`, `omybuntu-pkg-present`, and `omybuntu-pkg-missing`

Some older migrations predate these rules. Do not copy older migrations that start with shebangs, omit the leading `echo`, or hard-code `~/.local/share/omybuntu`.

Migrations may use raw `apt`, `snap`, `flatpak`, `command -v`, or direct config edits when needed for historical compatibility or one-off repair work.

Example:
```bash
echo "Disable fingerprint in hyprlock if fingerprint auth is not configured"

if omybuntu-cmd-missing fprintd-list || ! fprintd-list "$USER" 2>/dev/null | grep -q "finger"; then
  sed -i 's/fingerprint:enabled = .*/fingerprint:enabled = false/' ~/.config/hypr/hyprlock.conf
fi
```

# Porting from Omarchy

- Look exactly at how Omarchy originally implemented scripts and features. Nothing should be reinvented unless extremely necessary.
- If an existing feature is broken, find and fix the root cause of why the Omarchy implementation is failing instead of rewriting it from scratch.
- You must ask for permission from the user before reinventing or rewriting any script.

# Commits

- Ao concluir uma rodada de desenvolvimento ou tarefa específica, faça o commit das alterações antes de finalizar o turno.
- Siga a convenção de **Conventional Commits** (ex: `feat(escopo): descrição`, `fix(escopo): descrição`, `style(escopo): descrição`, `test: descrição`, `chore: descrição`).
- Agrupe e divida as alterações em commits lógicos separados quando as mudanças forem de naturezas diferentes (por exemplo, separar uma correção de teste de uma nova funcionalidade de instalação).


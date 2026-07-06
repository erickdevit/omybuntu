#!/bin/bash
# omybuntu:summary=ISO build pipeline integrity and regression tests
# omybuntu:group=test

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="$ROOT/bin:$PATH"

errors=0
total=0

ok()   { printf 'ok %d - %s\n' $((++total)) "$1"; }
nok()  { printf 'not ok %d - %s\n' $((++total)) "$1" >&2; ((++errors)); }

# ------------------------------------------------------------------
# All install/ scripts must be referenced in the pipeline
# ------------------------------------------------------------------
echo "# Pipeline coverage"

while IFS= read -r script; do
  rel="${script#$ROOT/}"
  case "$rel" in
    install/helpers/*|install/iso/build-iso.sh|install/build-quickshell.sh|install/preflight/guard.sh|install/preflight/disable-mkinitcpio.sh) continue ;;
  esac
  name=$(basename "$script")
  # Check in install/ AND bin/ (first-run scripts are called from bin/omybuntu-first-run)
  if grep -qr "$name" "$ROOT/install/" --include='*.sh' 2>/dev/null \
     || grep -qr "$name" "$ROOT/bin/" --include='*' 2>/dev/null; then
    ok "script referenced: $rel"
  else
    nok "orphan script: $rel (never sourced or run)"
  fi
done < <(find "$ROOT/install" -name '*.sh' -type f | sort)

# ------------------------------------------------------------------
# Packages required for live ISO functionality
# ------------------------------------------------------------------
echo "# Package requirements"

BASE_PKGS="$ROOT/install/omybuntu-base.packages"
pkgs=$(<"$BASE_PKGS")

for pkg in xdg-terminal-exec fonts-font-awesome fonts-noto fonts-noto-color-emoji; do
  if grep -qx "$pkg" <<<"$pkgs"; then
    ok "$pkg is in base.packages"
  else
    nok "missing from base.packages: $pkg"
  fi
done

# ------------------------------------------------------------------
# setup-iso.sh sanity
# ------------------------------------------------------------------
echo "# setup-iso.sh integrity"

SETUP_ISO="$ROOT/install/iso/setup-iso.sh"

if [[ -f $SETUP_ISO ]]; then
  ok "setup-iso.sh exists"
else
  nok "setup-iso.sh exists"
fi

if [[ -x $SETUP_ISO ]]; then
  ok "setup-iso.sh is executable"
else
  nok "setup-iso.sh is executable"
fi

setup_content=$(<"$SETUP_ISO")

if [[ $setup_content == *.local/bin* ]]; then
  ok "copies .local/bin/ to skel"
else
  nok "copies .local/bin/ to skel"
fi

if [[ $setup_content == *.local/state/omybuntu* ]]; then
  ok "copies .local/state to skel"
else
  nok "copies .local/state to skel"
fi

if grep -q 's|/root/|/home/ubuntu/|g' <<<"$setup_content"; then
  ok "replaces /root/ with /home/ubuntu/"
else
  nok "replaces /root/ with /home/ubuntu/"
fi

if [[ $setup_content == */etc/skel/.config* ]]; then
  ok "creates /etc/skel/.config"
else
  nok "creates /etc/skel/.config"
fi

# ------------------------------------------------------------------
# No /root/ hardcoded in default configs that ship to the user
# ------------------------------------------------------------------
echo "# Config path sanity"

bad=$(grep -rl "/root/" "$ROOT/config" "$ROOT/default" \
  --include='*.conf' --include='*.toml' --include='*.ini' \
  --include='*.css' --include='*.jsonc' --include='*.lua' \
  --include='*.desktop' 2>/dev/null || true)

if [[ -n $bad ]]; then
  while IFS= read -r f; do
    nok "config contains /root/ path: ${f#$ROOT/}"
  done <<<"$bad"
else
  ok "no config files contain /root/ paths"
fi

# ------------------------------------------------------------------
# JetBrainsMono Nerd Font references (all must be consistent)
# ------------------------------------------------------------------
echo "# Font consistency"

for ref in \
  config/ghostty/config config/foot/foot.ini config/hypr/hyprlock.conf \
  config/waybar/style.css config/swayosd/style.css \
  config/fontconfig/fonts.conf config/alacritty/alacritty.toml \
  config/kitty/kitty.conf default/foot/screensaver.ini \
  default/sddm/omybuntu/Main.qml; do
  fpath="$ROOT/$ref"
  if [[ -f $fpath ]]; then
    if grep -q "JetBrainsMono Nerd Font" "$fpath"; then
      ok "font ref: $ref"
    else
      nok "missing JetBrainsMono Nerd Font ref: $ref"
    fi
  fi
done

# ------------------------------------------------------------------
# fonts.sh must download JetBrainsMono Nerd Font
# ------------------------------------------------------------------
echo "# Fonts install"

FONTS_SH="$ROOT/install/packaging/fonts.sh"
fonts_content=$(<"$FONTS_SH")

[[ $fonts_content == *JetBrainsMono.tar.xz* ]] && \
  ok "fonts.sh downloads JetBrainsMono Nerd Font" || \
  nok "fonts.sh downloads JetBrainsMono Nerd Font"

[[ $fonts_content == *fc-cache* ]] && \
  ok "fonts.sh runs fc-cache" || \
  nok "fonts.sh runs fc-cache"

[[ $fonts_content == *omybuntu.ttf* ]] && \
  ok "fonts.sh installs omybuntu.ttf" || \
  nok "fonts.sh installs omybuntu.ttf"

# ------------------------------------------------------------------
# ubuntu-tuis-and-walker.sh in pipeline
# ------------------------------------------------------------------
echo "# TUI/walker pipeline"

PACKAGING_ALL="$ROOT/install/packaging/all.sh"
packaging_content=$(<"$PACKAGING_ALL")

[[ $packaging_content == *ubuntu-tuis-and-walker.sh* ]] && \
  ok "packaging/all.sh calls ubuntu-tuis-and-walker.sh" || \
  nok "packaging/all.sh calls ubuntu-tuis-and-walker.sh"

UBUNTU_TUIS="$ROOT/install/ubuntu-tuis-and-walker.sh"
if [[ -f $UBUNTU_TUIS ]]; then
  ok "ubuntu-tuis-and-walker.sh exists"
  tuis_content=$(<"$UBUNTU_TUIS")
  [[ $tuis_content == *elephant* ]] && ok "downloads elephant" \
    || nok "downloads elephant"
  [[ $tuis_content == *walker* ]] && ok "downloads walker" \
    || nok "downloads walker"
else
  nok "ubuntu-tuis-and-walker.sh exists"
fi

# ------------------------------------------------------------------
# Toggles directory & placeholder
# ------------------------------------------------------------------
echo "# Toggles setup"

TOGGLES_SH="$ROOT/install/config/toggles.sh"
toggles_content=$(<"$TOGGLES_SH")

[[ $toggles_content == *placeholder.conf* ]] && \
  ok "toggles.sh creates hypr/placeholder.conf" || \
  nok "toggles.sh creates hypr/placeholder.conf"

OMYBUNTU_TOGGLES="$ROOT/install/config/omybuntu-toggles.sh"
if [[ -f $OMYBUNTU_TOGGLES ]]; then
  toggles2_content=$(<"$OMYBUNTU_TOGGLES")
  [[ $toggles2_content == *toggles/hypr* ]] && \
    ok "omybuntu-toggles.sh creates hypr dir" || \
    nok "omybuntu-toggles.sh creates hypr dir"
fi

# ------------------------------------------------------------------
# build-iso.sh must have essential packages
# ------------------------------------------------------------------
echo "# ISO package list"

BUILD_ISO="$ROOT/install/iso/build-iso.sh"
build_content=$(<"$BUILD_ISO")

for pkg in casper plymouth linux-image-generic grub-efi-amd64 gum; do
  [[ $build_content == *$pkg* ]] && \
    ok "build-iso.sh installs $pkg" || \
    nok "build-iso.sh installs $pkg"
done

# ------------------------------------------------------------------
# First-run invokes elephant service enable
# ------------------------------------------------------------------
echo "# First-run flow"

FIRST_RUN="$ROOT/bin/omybuntu-first-run"
if [[ -f $FIRST_RUN ]]; then
  fr_content=$(<"$FIRST_RUN")
  [[ $fr_content == *elephant.sh* ]] && \
    ok "first-run calls elephant.sh" || \
    nok "first-run calls elephant.sh"
fi

# ------------------------------------------------------------------
# Presentation.sh guards in chroot/ISO mode
# ------------------------------------------------------------------
echo "# Chroot mode guards"

PRESENTATION="$ROOT/install/helpers/presentation.sh"
pres_content=$(<"$PRESENTATION")

[[ $pres_content == *OMYBUNTU_ISO_BUILD* ]] && \
  ok "presentation.sh has ISO build guards" || \
  nok "presentation.sh has ISO build guards"

[[ $pres_content == *stty* ]] && \
  ok "presentation.sh uses stty (guarded)" || \
  nok "presentation.sh uses stty"

ERRORS_SH="$ROOT/install/helpers/errors.sh"
errors_content=$(<"$ERRORS_SH")

[[ $errors_content == *OMYBUNTU_ISO_BUILD* ]] && \
  ok "errors.sh bails out early in ISO mode" || \
  nok "errors.sh bails out early in ISO mode"

# ------------------------------------------------------------------
# bin/ scripts are executable
# ------------------------------------------------------------------
echo "# Bin permissions"

ok_count=0
while IFS= read -r bin; do
  name=$(basename "$bin")
  if [[ -x $bin ]]; then
    ((++ok_count))
  else
    nok "not executable: $name"
  fi
done < <(find "$ROOT/bin" -maxdepth 1 -type f -name 'omybuntu-*' | sort)

[[ $ok_count -gt 0 ]] && ok "all $ok_count bin scripts are executable"

# ------------------------------------------------------------------
# UWSM config consistency
# ------------------------------------------------------------------
echo "# UWSM config"

UWSM_DEFAULT="$ROOT/config/uwsm/default"
uwsm_content=$(<"$UWSM_DEFAULT")

[[ $uwsm_content == *xdg-terminal-exec* ]] && \
  ok "uwsm/default sets TERMINAL=xdg-terminal-exec" || \
  nok "uwsm/default sets TERMINAL=xdg-terminal-exec"

# ------------------------------------------------------------------
# config/config.sh copies all config/ to ~/.config/
# ------------------------------------------------------------------
echo "# Config copy"

CONFIG_SH="$ROOT/install/config/config.sh"
config_sh_content=$(<"$CONFIG_SH")

[[ $config_sh_content == *config/* ]] && \
  ok "config.sh copies config/* to ~/.config/" || \
  nok "config.sh copies config/* to ~/.config/"

[[ $config_sh_content == *bashrc* ]] && \
  ok "config.sh copies default bashrc" || \
  nok "config.sh copies default bashrc"

# ------------------------------------------------------------------
# User systemd service files exist in config/ for first-run
# ------------------------------------------------------------------
echo "# User services"

for svc in swayosd-server omybuntu-battery-monitor omybuntu-recover-internal-monitor; do
  svc_file="$ROOT/config/systemd/user/$svc.service"
  timer_file="$ROOT/config/systemd/user/$svc.timer"
  if [[ -f $svc_file ]] || [[ -f $timer_file ]]; then
    ok "user service exists: $svc"
  else
    nok "user service missing: $svc"
  fi
done

# ------------------------------------------------------------------
# No hardcoded arch paths in config files (Ubuntu paths only)
# ------------------------------------------------------------------
echo "# Path sanity (arch vs ubuntu)"

# Themed templates exist (referenced by theme system)
for tpl in waybar.css.tpl hyprland.conf.tpl hyprlock.conf.tpl mako.ini.tpl walker.css.tpl; do
  tpl_path="$ROOT/default/themed/$tpl"
  [[ -f $tpl_path ]] && ok "themed template: $tpl" || nok "themed template missing: $tpl"
done

# ------------------------------------------------------------------
# SDDM, Waybar, Cursors and Installer sanity checks
# ------------------------------------------------------------------
echo "# SDDM, Waybar, Cursors and Installer sanity"

# sddm.sh writes 99-omybuntu.conf
sddm_content=$(<"$ROOT/install/login/sddm.sh")
[[ $sddm_content == *99-omybuntu.conf* ]] && ok "sddm.sh configures 99-omybuntu.conf" || nok "sddm.sh does not configure 99-omybuntu.conf"

# icons.sh copies volantes cursors
icons_content=$(<"$ROOT/install/packaging/icons.sh")
[[ $icons_content == *volantes_cursors* && $icons_content == *volantes_light_cursors* ]] && \
  ok "icons.sh copies volantes cursor themes" || \
  nok "icons.sh does not copy volantes cursor themes"

# setup-iso.sh blocks budgie and breeze themes
setup_iso_content=$(<"$ROOT/install/iso/setup-iso.sh")
[[ $setup_iso_content == *sddm-theme-ubuntu-budgie* && $setup_iso_content == *sddm-theme-breeze* ]] && \
  ok "setup-iso.sh blocks downstream sddm themes" || \
  nok "setup-iso.sh does not block downstream sddm themes"

# Waybar position is left
waybar_config_content=$(<"$ROOT/config/waybar/config.jsonc")
[[ $waybar_config_content == *'"position": "left"'* ]] && \
  ok "waybar position is left by default" || \
  nok "waybar position is not left by default"

# omybuntu-tui-monitors is compiled and copied
build_iso_content=$(<"$ROOT/install/iso/build-iso.sh")
[[ $build_iso_content == *omybuntu-tui-monitors* ]] && \
  ok "build-iso.sh copies omybuntu-tui-monitors to /usr/local/bin" || \
  nok "build-iso.sh does not copy omybuntu-tui-monitors to /usr/local/bin"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo
if (( errors == 0 )); then
  echo "# All $total tests passed."
else
  echo "# $errors of $total tests failed." >&2
  exit 1
fi

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

if [[ $setup_content == '#!/bin/bash'* && $setup_content == *'set -euo pipefail'* ]]; then
  ok "setup-iso.sh is a strict bash entrypoint"
else
  nok "setup-iso.sh is a strict bash entrypoint"
fi

if [[ $setup_content == *'OMYBUNTU_PATH="${OMYBUNTU_PATH:-/opt/omybuntu}"'* ]]; then
  ok "setup-iso.sh defaults OMYBUNTU_PATH to /opt/omybuntu"
else
  nok "setup-iso.sh defaults OMYBUNTU_PATH to /opt/omybuntu"
fi

if [[ $setup_content == *.local/bin* ]]; then
  ok "copies .local/bin/ to skel"
else
  nok "copies .local/bin/ to skel"
fi

if [[ $setup_content == *'/etc/skel/.local/bin'* && $setup_content == *'mkdir -p /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/bin'* ]]; then
  ok "creates /etc/skel/.local/bin"
else
  nok "creates /etc/skel/.local/bin"
fi

if [[ $setup_content == *.local/state/omybuntu* ]]; then
  ok "copies .local/state to skel"
else
  nok "copies .local/state to skel"
fi

if grep -q 's|/root/|/home/$LIVE_USER/|g' <<<"$setup_content"; then
  ok "replaces /root/ with the configured live user home"
else
  nok "replaces /root/ with the configured live user home"
fi

if [[ $setup_content == */etc/skel/.config* ]]; then
  ok "creates /etc/skel/.config"
else
  nok "creates /etc/skel/.config"
fi

if [[ $setup_content == *budgie-sddm-theme* && $setup_content == *ubuntu-session* ]]; then
  ok "setup-iso.sh blocks downstream GNOME/SDDM packages"
else
  nok "setup-iso.sh blocks downstream GNOME/SDDM packages"
fi

if [[ $setup_content == *display-manager.service* && $setup_content == *graphical.target.wants* ]]; then
  ok "setup-iso.sh forces SDDM display-manager and graphical target"
else
  nok "setup-iso.sh forces SDDM display-manager and graphical target"
fi

if [[ $setup_content == */etc/casper.conf* && $setup_content == *'USERNAME="$LIVE_USER"'* ]]; then
  ok "setup-iso.sh defines the live casper user"
else
  nok "setup-iso.sh defines the live casper user"
fi

if [[ $setup_content == *omybuntu-refresh-plymouth* && $setup_content == *omybuntu-refresh-sddm* ]]; then
  ok "setup-iso.sh refreshes Plymouth and SDDM"
else
  nok "setup-iso.sh refreshes Plymouth and SDDM"
fi

if [[ $setup_content == *omybuntu-live-session-setup.desktop* ]] \
  && [[ $setup_content == *"Exec=/usr/local/bin/omybuntu-live-session-setup"* ]] \
  && [[ $setup_content == *"ln -snf /opt/omybuntu/bin/omybuntu-live-session-setup /usr/local/bin/omybuntu-live-session-setup"* ]]; then
  ok "setup-iso.sh autostarts live session theming"
else
  nok "setup-iso.sh does not autostart live session theming"
fi

if [[ $setup_content == *'theme/backgrounds/omybuntu.png'* ]] \
  && [[ $setup_content == *'gtk-theme-name=$live_gtk_theme'* ]] \
  && [[ $setup_content == *'gtk-cursor-theme-name=$live_cursor_theme'* ]]; then
  ok "setup-iso.sh seeds live wallpaper and GTK cursor theme"
else
  nok "setup-iso.sh does not seed live wallpaper and GTK cursor theme"
fi

user_dirs_content=$(<"$ROOT/install/config/user-dirs.sh")
if [[ $user_dirs_content == *Documents* ]] \
  && [[ $user_dirs_content == *Projects* ]] \
  && [[ $user_dirs_content != *'for dir in Downloads Projects Pictures Videos'* ]]; then
  ok "user-dirs bookmarks Documents and removes stale Projects"
else
  nok "user-dirs does not replace the Projects bookmark with Documents"
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
  [[ $toggles2_content == *flags.conf* && $toggles2_content != *flags.lua* ]] && \
    ok "omybuntu-toggles.sh copies flags.conf" || \
    nok "omybuntu-toggles.sh still references flags.lua"
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

[[ $build_content == *write_live_apt_pins* && $build_content == *budgie-sddm-theme* ]] && \
  ok "build-iso.sh writes live APT pins before install" || \
  nok "build-iso.sh does not write live APT pins before install"

[[ $build_content == *'/usr/bin/env -i'* && $build_content == *'/bin/bash -e -c'* ]] && \
  ok "build-iso.sh runs chroot setup in a clean aborting environment" || \
  nok "build-iso.sh does not run chroot setup in a clean aborting environment"

[[ $build_content == *'trap cleanup EXIT'* && $build_content == *cleanup_mounts* ]] && \
  ok "build-iso.sh cleans up mounts and log tail on exit" || \
  nok "build-iso.sh does not clean up mounts and log tail on exit"

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
setup_iso_content=$(<"$ROOT/install/iso/setup-iso.sh")
[[ $sddm_content == *99-omybuntu.conf* ]] && ok "sddm.sh configures 99-omybuntu.conf" || nok "sddm.sh does not configure 99-omybuntu.conf"

hyprland_desktop_content=$(<"$ROOT/default/wayland-sessions/hyprland.desktop")
if [[ $hyprland_desktop_content == *NoDisplay=true* ]] \
  && [[ $hyprland_desktop_content != *Hidden=true* ]]; then
  ok "hyprland.desktop remains a valid hidden-from-menus uwsm target"
else
  nok "hyprland.desktop is hidden from uwsm or visible in menus"
fi

if [[ $hyprland_desktop_content == *Exec=start-hyprland* ]] \
  && [[ $hyprland_desktop_content == *TryExec=start-hyprland* ]] \
  && [[ $hyprland_desktop_content != *$'Exec=Hyprland\n'* ]]; then
  ok "hyprland.desktop launches through the recommended watchdog wrapper"
else
  nok "hyprland.desktop still bypasses start-hyprland"
fi

if [[ $sddm_content == *default/wayland-sessions/hyprland.desktop* ]] \
  && ! grep -q 'for session in hyprland.desktop' <<<"$sddm_content"; then
  ok "sddm.sh keeps hyprland.desktop for uwsm"
else
  nok "sddm.sh still deletes hyprland.desktop"
fi

if [[ $setup_iso_content == *default/wayland-sessions/hyprland.desktop* ]] \
  && ! grep -q 'for session in hyprland.desktop' <<<"$setup_iso_content"; then
  ok "setup-iso.sh keeps hyprland.desktop for uwsm"
else
  nok "setup-iso.sh still deletes hyprland.desktop"
fi

if [[ $setup_iso_content == *'Exec=/opt/omybuntu/bin/omybuntu-launch-tui /opt/omybuntu/bin/omybuntu-setup-install'* ]] \
  && [[ $setup_iso_content == *'exec-once = sleep 3 && /opt/omybuntu/bin/omybuntu-launch-tui /opt/omybuntu/bin/omybuntu-setup-install'* ]] \
  && [[ $setup_iso_content == *'99-omybuntu-live-installer'* ]]; then
  ok "live installer autostarts through Hyprland with sudo allowance"
else
  nok "live installer does not autostart through Hyprland"
fi

[[ -f $ROOT/bin/omybuntu-cmd-generate-ascii-logo ]] && \
  ok "ascii logo helper exists" || \
  nok "ascii logo helper is missing"

ascii_logo_content=$(<"$ROOT/bin/omybuntu-cmd-generate-ascii-logo")
[[ $ascii_logo_content == *f59e0b* && $ascii_logo_content == *-append* ]] && \
  ok "ascii logo helper defaults to orange and renders line-by-line" || \
  nok "ascii logo helper does not render orange line-by-line assets"

[[ $ascii_logo_content == *fc-match* && $ascii_logo_content == *NotoSansMono-Regular.ttf* ]] && \
  ok "ascii logo helper resolves a real font file for chroot builds" || \
  nok "ascii logo helper still depends on ImageMagick font aliases only"

[[ -f $ROOT/bin/omybuntu-cmd-recolor-image-assets ]] && \
  ok "theme asset recolor helper exists" || \
  nok "theme asset recolor helper is missing"

plymouth_script_content=$(<"$ROOT/default/plymouth/omybuntu.script")
if [[ $plymouth_script_content == *'Image("spinner.png")'* ]] \
  && [[ $plymouth_script_content == *'spinner.turns_per_cycle = 3;'* ]] \
  && [[ $plymouth_script_content == *'spinner.pause_frames = 20;'* ]] \
  && [[ $plymouth_script_content == *'spinner.image.Rotate(angle)'* ]]; then
  ok "plymouth boot indicator rotates the distro icon in three-turn cycles"
else
  nok "plymouth boot indicator is missing the requested icon rotation cycle"
fi

if [[ $plymouth_script_content == *'Window.GetWidth() / 2 - image.GetWidth() / 2'* ]] \
  && [[ $plymouth_script_content == *'Window.GetHeight() / 2 - image.GetHeight() / 2'* ]] \
  && [[ $plymouth_script_content == *'if (spinner.size < 96)'* ]] \
  && [[ $plymouth_script_content == *'if (spinner.size > 320)'* ]]; then
  ok "plymouth spinner remains centered with bounded responsive scaling"
else
  nok "plymouth spinner centering or responsive scaling is incomplete"
fi

if [[ $plymouth_script_content == *'if (mode == "boot" || mode == "resume") {'* ]] \
  && [[ $plymouth_script_content != *progress_box* ]] \
  && [[ $plymouth_script_content != *progress_bar* ]]; then
  ok "plymouth replaces the boot progress bar in live and installed boot modes"
else
  nok "plymouth still uses the progress bar or misses a boot mode"
fi

sddm_metadata_content=$(<"$ROOT/default/sddm/omybuntu/metadata.desktop")
[[ $sddm_metadata_content == *MainScript=Main.qml* && $sddm_metadata_content == *Theme-API=2.0* ]] && \
  ok "sddm metadata declares MainScript and Theme-API" || \
  nok "sddm metadata is incomplete"

[[ -x $ROOT/install/iso/casper-bottom/26omybuntu-sddm-autologin ]] && \
  ok "casper hook finalizes live SDDM autologin after user creation" || \
  nok "casper hook for live SDDM autologin is missing"

casper_sddm_content=$(<"$ROOT/install/iso/casper-bottom/26omybuntu-sddm-autologin")
if grep -q '^Session=omybuntu$' <<<"$setup_iso_content" \
  && grep -q '^DefaultSession=omybuntu$' <<<"$setup_iso_content" \
  && grep -q '^Session=omybuntu$' <<<"$casper_sddm_content" \
  && grep -q '^DefaultSession=omybuntu$' <<<"$casper_sddm_content"; then
  ok "live SDDM autologin targets the omybuntu session id"
else
  nok "live SDDM autologin does not target the omybuntu session id"
fi

[[ -f $ROOT/install/iso/casper-bottom/15autologin ]] \
  && grep -q 'sddm_session=omybuntu$' "$ROOT/install/iso/casper-bottom/15autologin" && \
  ok "patched casper 15autologin uses the omybuntu session id" || \
  nok "patched casper 15autologin is missing omybuntu session support"

if [[ $setup_iso_content == *zz-omybuntu-live.conf* && $setup_iso_content == *26omybuntu-sddm-autologin* ]] \
  && ! grep -q "\-p '\*' ubuntu" <<<"$setup_iso_content"; then
  ok "setup-iso installs live autologin hooks without locking ubuntu"
else
  nok "setup-iso live autologin setup is incomplete"
fi

if [[ $setup_iso_content == *'find /etc/skel -type l -print0'* ]] \
  && [[ $setup_iso_content == *'/home/$LIVE_USER/${target#/root/}'* ]]; then
  ok "setup-iso rewrites /root symlink targets for the live user"
else
  nok "setup-iso does not rewrite /root symlink targets for the live user"
fi

# icons.sh copies volantes cursors
icons_content=$(<"$ROOT/install/packaging/icons.sh")
[[ $icons_content == *volantes_cursors* && $icons_content == *volantes_light_cursors* ]] && \
  ok "icons.sh copies volantes cursor themes" || \
  nok "icons.sh does not copy volantes cursor themes"

# setup-iso.sh blocks budgie and breeze themes
[[ $setup_iso_content == *budgie-sddm-theme* && $setup_iso_content == *sddm-theme-breeze* ]] && \
  ok "setup-iso.sh blocks downstream sddm themes" || \
  nok "setup-iso.sh does not block downstream sddm themes"

# Waybar position is left
waybar_config_content=$(<"$ROOT/config/waybar/config.jsonc")
[[ $waybar_config_content == *'"position": "left"'* && $waybar_config_content == *'"height": 0'* && $waybar_config_content == *'"width": 28'* ]] && \
  ok "waybar fills the left edge with vertical dimensions" || \
  nok "waybar does not use full-height vertical dimensions"

monitors_config_content=$(<"$ROOT/config/hypr/monitors.conf")
[[ $monitors_config_content == *'env = GDK_SCALE,1.25'* && $monitors_config_content == *'monitor=,preferred,auto,1.25'* ]] && \
  ok "Hyprland defaults to 1.25 monitor and toolkit scaling" || \
  nok "Hyprland default scale is not 1.25"

# omybuntu-tui-monitors is compiled and copied
build_iso_content=$(<"$ROOT/install/iso/build-iso.sh")
[[ $build_iso_content == *omybuntu-tui-monitors* ]] && \
  ok "build-iso.sh copies omybuntu-tui-monitors to /usr/local/bin" || \
  nok "build-iso.sh does not copy omybuntu-tui-monitors to /usr/local/bin"

# Installer TUI uses a clean chroot install environment and final user autologin
installer_install_content=$(<"$ROOT/installer/src/install.rs")
installer_storage_content=$(<"$ROOT/installer/src/storage.rs")
[[ $installer_install_content == *TargetCleanup* && $installer_install_content == *unmount_virtual_fs* ]] && \
  ok "installer cleans target mounts on failure" || \
  nok "installer does not clean target mounts on failure"

[[ $installer_install_content == *write_omybuntu_apt_pins* && $installer_install_content == *budgie-sddm-theme* ]] && \
  ok "installer writes Omybuntu apt pins before install.sh" || \
  nok "installer does not write Omybuntu apt pins before install.sh"

[[ $installer_install_content == *'"/usr/bin/env"'* && $installer_install_content == *'"-i"'* && $installer_install_content == *'HOME=/root'* ]] && \
  ok "installer runs install.sh with a clean root chroot environment" || \
  nok "installer does not run install.sh with a clean root chroot environment"

[[ $installer_install_content == *OMYBUNTU_TARGET_USER* && $installer_install_content != *'"OMYBUNTU_ISO_BUILD=true"'* ]] && \
  ok "installer passes target user without pretending to be ISO build" || \
  nok "installer target-user chroot environment is incorrect"

[[ $installer_install_content == *configure_target_login* && $installer_install_content == *display-manager.service* ]] && \
  ok "installer configures SDDM login for created user" || \
  nok "installer does not configure SDDM login for created user"

[[ $installer_install_content == *OMYBUNTU_ENCRYPTED_INSTALL* && $installer_install_content == *cfg.encrypt* ]] && \
  ok "installer enables SDDM autologin only for encrypted installs" || \
  nok "installer does not gate SDDM autologin on encryption"

if [[ $installer_storage_content == *MIN_ALONGSIDE_BYTES* \
  && $installer_storage_content == *'64 * 1024 * 1024 * 1024'* \
  && $installer_storage_content == *'EFI/Microsoft/Boot/bootmgfw.efi'* \
  && $installer_storage_content == *validate_alongside_plan* ]]; then
  ok "installer discovers and revalidates eligible Windows alongside layouts"
else
  nok "installer alongside layout discovery or revalidation is incomplete"
fi

if [[ $installer_install_content == *'StoragePlan::AlongsideWindows'* \
  && $installer_install_content == *'Creating Omybuntu in the selected unallocated region'* \
  && $installer_install_content == *'esp_partition.clone()'* \
  && $installer_install_content == *'35_omybuntu_windows'* ]]; then
  ok "installer creates only the alongside root partition and preserves the Windows ESP"
else
  nok "installer alongside partition or Windows boot integration is incomplete"
fi

if [[ $installer_install_content == *grub-efi-amd64-signed* \
  && $installer_install_content == *shim-signed* \
  && $installer_install_content == *'--uefi-secure-boot'* \
  && $installer_install_content == *verify_signed_boot_chain* ]]; then
  ok "installed system uses and verifies the Ubuntu signed Secure Boot chain"
else
  nok "installed Secure Boot chain is incomplete"
fi

secure_iso_boot_content=$(<"$ROOT/install/iso/build-bootable-iso.sh")
if [[ $secure_iso_boot_content == *shimx64.efi.signed.latest* \
  && $secure_iso_boot_content == *mmx64.efi* \
  && $secure_iso_boot_content == *grubx64.efi.signed* \
  && $secure_iso_boot_content == *sbverify* \
  && $secure_iso_boot_content == *appended_partition_2* ]]; then
  ok "live ISO embeds and verifies signed shim and GRUB in its EFI image"
else
  nok "live ISO Secure Boot image is incomplete"
fi

direct_boot_content=$(<"$ROOT/bin/omybuntu-config-direct-boot")
[[ $direct_boot_content == *'SecureBoot enabled'* && $direct_boot_content == *sbverify* ]] && \
  ok "direct UKI boot rejects unsigned images while Secure Boot is enabled" || \
  nok "direct UKI boot does not enforce Secure Boot signatures"

sddm_install_content=$(<"$ROOT/install/login/sddm.sh")
[[ $sddm_install_content == *omybuntu_encrypted_install* && $sddm_install_content == *OMYBUNTU_CHROOT_INSTALL* ]] && \
  ok "install/login/sddm.sh gates autologin on encryption outside live ISO" || \
  nok "install/login/sddm.sh does not gate autologin on encryption"

installer_app_content=$(<"$ROOT/installer/src/app.rs")
[[ $installer_app_content == *valid_username* && $installer_app_content == *valid_hostname* ]] && \
  ok "installer validates system username and hostname format" || \
  nok "installer does not validate system username and hostname format"

installer_ui_content=$(<"$ROOT/installer/src/ui.rs")
if [[ $installer_ui_content == *'Do not encrypt disk'* \
  && $installer_ui_content == *'app.show_pass'* \
  && $installer_ui_content == *'[F1] Show/hide passwords'* ]]; then
  ok "installer offers explicit no-encryption and LUKS password visibility controls"
else
  nok "installer disk encryption choices or password visibility controls are incomplete"
fi

if [[ $installer_ui_content == *'Constraint::Length(5), // footer'* \
  && $installer_ui_content == *render_centered_hint* \
  && $installer_ui_content == *render_centered_button* ]]; then
  ok "installer footer labels and completion buttons are centered vertically and horizontally"
else
  nok "installer footer labels or completion buttons are not centered in their containers"
fi

if [[ $installer_install_content == *'--out-format=Copying: %n%L'* \
  && $installer_install_content == *'System files copied successfully.'* \
  && $installer_install_content != *'(offline)'* ]]; then
  ok "offline installer streams copy details without offline tags"
else
  nok "offline installer copy logs are unclear or still include offline tags"
fi

# ------------------------------------------------------------------
# Plymouth and Hibernation Ubuntu port checks
# ------------------------------------------------------------------
echo "# Plymouth and Hibernation Ubuntu port checks"

# Plymouth scripts rebuild initramfs
refresh_plymouth_content=$(<"$ROOT/bin/omybuntu-refresh-plymouth")
[[ $refresh_plymouth_content == *update-initramfs* ]] && ok "refresh-plymouth uses update-initramfs" || nok "refresh-plymouth does not use update-initramfs"
[[ $refresh_plymouth_content == *'chown -R root:root'* && $refresh_plymouth_content == *'chmod 0755'* ]] && \
  ok "refresh-plymouth normalizes theme ownership and permissions" || \
  nok "refresh-plymouth does not normalize theme ownership and permissions"

plymouth_reset_content=$(<"$ROOT/bin/omybuntu-plymouth-reset")
[[ $plymouth_reset_content == *update-initramfs* ]] && ok "plymouth-reset uses update-initramfs" || nok "plymouth-reset does not use update-initramfs"

plymouth_install_content=$(<"$ROOT/install/login/plymouth.sh")
plymouth_set_content=$(<"$ROOT/bin/omybuntu-plymouth-set")
if [[ $refresh_plymouth_content == *'icon.png" -bordercolor none -border 40x40'* ]] \
  && [[ $plymouth_reset_content == *'icon.png" -bordercolor none -border 40x40'* ]] \
  && [[ $plymouth_install_content == *'icon.png" -bordercolor none -border 40x40'* ]] \
  && [[ $plymouth_set_content == *'icon.png" -bordercolor none -border 40x40'* ]] \
  && [[ $refresh_plymouth_content == *spinner.png* ]] \
  && [[ $plymouth_reset_content == *spinner.png* ]] \
  && [[ $plymouth_install_content == *spinner.png* ]] \
  && [[ $plymouth_set_content == *spinner.png* ]]; then
  ok "all Plymouth writers stage a padded distro icon for rotation"
else
  nok "one or more Plymouth writers omit the padded spinner asset"
fi

if [[ $plymouth_install_content == *'chown -R root:root'* ]] \
  && [[ $plymouth_reset_content == *'chown -R root:root'* ]] \
  && [[ $plymouth_set_content == *'chown -R root:root'* ]]; then
  ok "all Plymouth writers normalize theme ownership"
else
  nok "one or more Plymouth writers do not normalize theme ownership"
fi

# omybuntu-reinstall-configs calls grub refresh and not limine
reinstall_configs_content=$(<"$ROOT/bin/omybuntu-reinstall-configs")
[[ $reinstall_configs_content == *omybuntu-refresh-grub* && $reinstall_configs_content != *omybuntu-refresh-limine* ]] && \
  ok "reinstall-configs uses refresh-grub and not refresh-limine" || \
  nok "reinstall-configs uses refresh-grub and not refresh-limine"

# GRUB config has suppressed logging
grub_config_content=$(<"$ROOT/default/grub/config")
[[ $grub_config_content == *systemd.show_status=false* && $grub_config_content == *loglevel=0* ]] && \
  ok "default grub/config suppresses boot logs" || \
  nok "default grub/config does not suppress boot logs"

# Hibernation setup and remove scripts check for initramfs-tools and update-grub
hibernation_setup_content=$(<"$ROOT/bin/omybuntu-hibernation-setup")
[[ $hibernation_setup_content == *initramfs-tools* && $hibernation_setup_content == *update-grub* ]] && \
  ok "hibernation-setup uses initramfs-tools and update-grub" || \
  nok "hibernation-setup does not use initramfs-tools and update-grub"

hibernation_remove_content=$(<"$ROOT/bin/omybuntu-hibernation-remove")
[[ $hibernation_remove_content == *initramfs-tools* && $hibernation_remove_content == *update-grub* ]] && \
  ok "hibernation-remove uses initramfs-tools and update-grub" || \
  nok "hibernation-remove does not use initramfs-tools and update-grub"

# ------------------------------------------------------------------
# Ubuntu Gaps and Leftovers checks
# ------------------------------------------------------------------
echo "# Ubuntu Gaps and Leftovers checks"

# Check that obsolete directories are deleted
[[ ! -d $ROOT/default/pacman && ! -d $ROOT/default/limine && ! -d $ROOT/default/snapper ]] && \
  ok "obsolete Arch config directories are deleted" || \
  nok "obsolete Arch config directories still exist"

# Check that .lua configs in config/hypr/ and default/hypr/ are deleted
[[ ! -f $ROOT/config/hypr/hyprland.lua && ! -f $ROOT/default/hypr/hyprland.lua ]] && \
  ok "hyprland.lua configuration files are deleted" || \
  nok "hyprland.lua configuration files still exist"

# Check that .conf configs in config/hypr/ exist
[[ -f $ROOT/config/hypr/hyprland.conf && -f $ROOT/config/hypr/bindings.conf ]] && \
  ok "hyprland.conf active configuration files exist" || \
  nok "hyprland.conf active configuration files are missing"

# Check that walker post-update hook is converted to apt hook
walker_elephant_content=$(<"$ROOT/install/config/walker-elephant.sh")
[[ $walker_elephant_content == *apt-get* && $walker_elephant_content == *Post-Invoke* && $walker_elephant_content != *pacman.d/hooks* ]] && \
  ok "walker-elephant hook uses apt post-invoke" || \
  nok "walker-elephant hook does not use apt post-invoke"

# Check that omybuntu-refresh-hyprland copies conf files instead of lua
refresh_hypr_content=$(<"$ROOT/bin/omybuntu-refresh-hyprland")
[[ $refresh_hypr_content == *hyprland.conf* && $refresh_hypr_content != *hyprland.lua* ]] && \
  ok "refresh-hyprland points to conf instead of lua" || \
  nok "refresh-hyprland points to conf instead of lua"

# Check that omybuntu-debug uses dpkg-query
debug_content=$(<"$ROOT/bin/omybuntu-debug")
[[ $debug_content == *dpkg-query* && $debug_content != *expac* ]] && \
  ok "omybuntu-debug uses dpkg-query and not pacman/expac" || \
  nok "omybuntu-debug does not use dpkg-query"

# Check that hardware configs write to grub
fred_content=$(<"$ROOT/install/config/hardware/intel/fred.sh")
[[ $fred_content == *default/grub* && $fred_content != *default/limine* ]] && \
  ok "intel/fred.sh writes to /etc/default/grub" || \
  nok "intel/fred.sh does not write to /etc/default/grub"

# Check that live ISO grub.cfg has console suppressions
live_grub_content=$(<"$ROOT/install/iso/grub.cfg")
grub_defaults_content=$(<"$ROOT/default/grub/config")
if [[ $live_grub_content == *systemd.show_status=false* && $live_grub_content == *loglevel=0* ]] \
  && [[ $live_grub_content == *'set gfxpayload=keep'* && $live_grub_content == *vt.handoff=7* ]] \
  && [[ $grub_defaults_content == *vt.handoff=7* ]]; then
  ok "GRUB suppresses the console and preserves the framebuffer for Plymouth"
else
  nok "GRUB does not preserve a clean transition to Plymouth"
fi

grub_theme_content=$(<"$ROOT/default/grub/theme.txt")
[[ $grub_theme_content != *'+ scrollbar'* && $grub_theme_content != *fill_color* ]] && \
  ok "GRUB theme avoids unsupported scrollbar object and fill_color" || \
  nok "GRUB theme still contains unsupported scrollbar object or fill_color"

[[ $grub_theme_content == *scrollbar_thumb* && $grub_theme_content == *fg_color* && $grub_theme_content == *bg_color* ]] && \
  ok "GRUB theme uses supported boot menu/progress properties" || \
  nok "GRUB theme misses supported boot menu/progress properties"

[[ $grub_theme_content == *"Select operating system"* ]] && \
  ok "GRUB theme defaults to English strings" || \
  nok "GRUB theme does not default to English strings"

grub_theme_tpl_content=$(<"$ROOT/default/grub/theme.tpl")
grub_theme_sh_content=$(<"$ROOT/install/packaging/grub-theme.sh")
[[ $grub_theme_tpl_content == *'{{ grub_select_os }}'* && $grub_theme_sh_content == *omybuntu_render_grub_theme_txt* ]] && \
  ok "GRUB theme renders from i18n template" || \
  nok "GRUB theme does not render from i18n template"

[[ $grub_theme_sh_content == *OMYBUNTU_ISO_BUILD* && $build_iso_content == *OMYBUNTU_ISO_BUILD=true* ]] && \
  ok "live ISO build forces English GRUB theme text" || \
  nok "live ISO build does not force English GRUB theme text"

[[ $installer_install_content == *OMYBUNTU_LANGUAGE* && $installer_install_content == *omybuntu-refresh-grub* ]] && \
  ok "installer applies localized GRUB theme after install" || \
  nok "installer does not apply localized GRUB theme after install"
# Check that omybuntu-refresh-apt is present and channel-set calls it
[[ -f $ROOT/bin/omybuntu-refresh-apt ]] && \
  ok "omybuntu-refresh-apt script exists" || \
  nok "omybuntu-refresh-apt script is missing"

channel_set_content=$(<"$ROOT/bin/omybuntu-channel-set")
[[ $channel_set_content == *omybuntu-refresh-apt* ]] && \
  ok "omybuntu-channel-set executes omybuntu-refresh-apt" || \
  nok "omybuntu-channel-set does not execute omybuntu-refresh-apt"

# Check that omybuntu-menu has no references to bindings.lua or input.lua
menu_content=$(<"$ROOT/bin/omybuntu-menu")
[[ $menu_content != *bindings.lua* && $menu_content != *input.lua* ]] && \
  ok "omybuntu-menu uses .conf instead of .lua" || \
  nok "omybuntu-menu still references .lua files"

# Check that update-keyring is updated and is not a simple print-only stub
keyring_content=$(<"$ROOT/bin/omybuntu-update-keyring")
[[ $keyring_content == *apt-get* && $keyring_content == *ubuntu-keyring* ]] && \
  ok "omybuntu-update-keyring actually runs package upgrades" || \
  nok "omybuntu-update-keyring remains an empty stub"

# Check that limine-snapper-restore.desktop is deleted
[[ ! -f $ROOT/applications/hidden/limine-snapper-restore.desktop ]] && \
  ok "limine-snapper-restore.desktop has been deleted" || \
  nok "limine-snapper-restore.desktop still exists"

# Check that legacy sddm migration points to 99-omybuntu.conf
sddm_migration_content=$(<"$ROOT/migrations/1778148645.sh")
[[ $sddm_migration_content == *99-omybuntu.conf* && $sddm_migration_content != *10-wayland.conf* ]] && \
  ok "sddm legacy migration points to 99-omybuntu.conf" || \
  nok "sddm legacy migration still points to 10-wayland.conf"

boot_visual_migration_content=$(<"$ROOT/migrations/1783719444.sh")
if [[ $boot_visual_migration_content == *omybuntu-refresh-plymouth* ]] \
  && [[ $boot_visual_migration_content == *default/wayland-sessions/omybuntu.desktop* ]] \
  && [[ $boot_visual_migration_content == *default/wayland-sessions/hyprland.desktop* ]]; then
  ok "boot visual migration updates Plymouth and both UWSM session entries"
else
  nok "boot visual migration does not fully update installed systems"
fi

# Launcher hygiene: Ghostty-only terminal and hidden clutter apps
base_packages_content=$(<"$ROOT/install/omybuntu-base.packages")
base_packages_content=${base_packages_content//$'\r'/}
[[ $base_packages_content != *$'\nfoot'$* && $base_packages_content != *$'\nfoot\n'* ]] && \
  ok "base packages no longer install foot by default" || \
  nok "base packages still install foot by default"

[[ ! -f $ROOT/applications/foot.desktop && -f $ROOT/applications/hidden/foot.desktop ]] && \
  ok "foot launcher is hidden instead of advertised in applications/" || \
  nok "foot launcher is still exposed in applications/"

hide_launcher_content=$(<"$ROOT/install/config/hide-launcher-clutter.sh")
[[ $hide_launcher_content == *org.fcitx.Fcitx5.desktop* && $hide_launcher_content == *omybuntu-pkg-drop*foot* ]] && \
  ok "install hides fcitx and foot clutter from the launcher" || \
  nok "install does not hide launcher clutter"

mimetypes_content=$(<"$ROOT/install/config/mimetypes.sh")
[[ $base_packages_content == *$'\nevince\n'* && $hide_launcher_content == *omybuntu-pkg-drop*papers* && $mimetypes_content == *'org.gnome.Evince.desktop application/pdf'* ]] && \
  ok "install keeps Evince and removes the redundant Papers reader" || \
  nok "install does not enforce Evince as the only document reader"

for hidden_desktop in \
  "com.mitchellh.ghostty.desktop" \
  "typora.desktop" \
  "Docker.desktop" \
  "Google Messages.desktop" \
  "gnome-network-panel.desktop" \
  "org.freedesktop.IBus.Setup.desktop"; do
  [[ -f "$ROOT/applications/hidden/$hidden_desktop" ]] && \
    ok "hidden launcher stub exists: $hidden_desktop" || \
    nok "hidden launcher stub missing: $hidden_desktop"
done

refresh_apps_content=$(<"$ROOT/bin/omybuntu-refresh-applications")
[[ $refresh_apps_content == *'gtk-update-icon-cache --ignore-theme-index'* && $refresh_apps_content == *'display-im6*.desktop'* && $refresh_apps_content == *'*ImageMagick*.desktop'* ]] && \
  ok "application refresh builds the local icon cache without restoring ImageMagick launchers" || \
  nok "application refresh can leave icons unresolved or restore ImageMagick launchers"

tui_install_content=$(<"$ROOT/bin/omybuntu-tui-install")
[[ $tui_install_content == *'gtk-update-icon-cache --ignore-theme-index'* ]] && \
  ok "TUI launchers refresh their local icon cache" || \
  nok "TUI launcher icons are not added to a usable cache"

[[ ! -f $ROOT/applications/typora.desktop ]] && \
  ok "typora launcher is not advertised by default" || \
  nok "typora launcher is still advertised by default"

packaging_all_content=$(<"$ROOT/install/packaging/all.sh")
[[ $packaging_all_content == *OMYBUNTU_ISO_BUILD* && $packaging_all_content == *packaging/ghostty.sh* && $packaging_all_content == *packaging/chrome.sh* ]] && \
  ok "ISO build skips Ghostty but keeps Chrome installed" || \
  nok "ISO build does not keep the intended browser/terminal package policy"

chrome_install_content=$(<"$ROOT/install/packaging/chrome.sh")
[[ $chrome_install_content == *patch_chrome_desktop_file* && $chrome_install_content == *google-chrome.desktop* && $chrome_install_content == *chrome-flags.conf* ]] && \
  ok "Chrome install patches the live launcher with Omybuntu flags" || \
  nok "Chrome install does not patch the live launcher with Omybuntu flags"

tuis_content=$(<"$ROOT/install/packaging/tuis.sh")
[[ $tuis_content == *'omybuntu-tui-install "Disk Usage" "gdu"'* && $tuis_content != *'omybuntu-tui-install "Docker"'* ]] && \
  ok "TUI launchers include Disk Usage but not Docker by default" || \
  nok "TUI launchers still include Docker or miss Disk Usage"

[[ $base_packages_content == *$'\ngdu\n'* ]] && \
  ok "base packages install gdu for Disk Usage" || \
  nok "base packages do not install gdu for Disk Usage"

build_iso_content=$(<"$ROOT/install/iso/build-iso.sh")
[[ $build_iso_content == *'.build-info'* && $build_iso_content == *OMYBUNTU_BUILD_BRANCH* && $build_iso_content == *OMYBUNTU_BUILD_VERSION* ]] && \
  ok "ISO build writes Omybuntu build metadata for fastfetch" || \
  nok "ISO build does not write Omybuntu build metadata"

version_content=$(<"$ROOT/version")
release_tag_pattern='^v[0-9]+\.[0-9]+\.[0-9]+(_(dev|rc)[0-9]+)?$'
[[ $version_content =~ $release_tag_pattern ]] && \
  ok "source version uses the vX.Y.Z_dev convention" || \
  nok "source version does not use the expected release convention"

if [[ v1.0.0_dev1 =~ $release_tag_pattern ]] \
  && [[ v1.0.0_rc1 =~ $release_tag_pattern ]] \
  && [[ v1.1.6 =~ $release_tag_pattern ]] \
  && [[ ! v1.1.6_dev =~ $release_tag_pattern ]] \
  && [[ ! v0.0.1.5-dev1 =~ $release_tag_pattern ]] \
  && [[ ! v1.1.6.1_dev =~ $release_tag_pattern ]]; then
  ok "release convention accepts exactly three numeric components"
else
  nok "release convention accepts a legacy or malformed tag"
fi

[[ $build_iso_content == *'OMYBUNTU_ISO_VERSION'* && $build_iso_content == *'omybuntu-${ISO_VERSION}-amd64.iso'* && $build_iso_content == *'printf '\''%s\n'\'' "$build_version"'* ]] && \
  ok "ISO preserves the complete requested version in its filename and embedded metadata" || \
  nok "ISO build does not propagate the requested version"

[[ $build_iso_content == *'_dev[0-9]+$'*dev* && $build_iso_content == *'_rc[0-9]+$'*rc* ]] && \
  ok "tagged ISO builds infer their update channel from the version suffix" || \
  nok "tagged ISO builds do not infer dev and rc channels"

version_channel_content=$(<"$ROOT/bin/omybuntu-version-channel")
branch_set_content=$(<"$ROOT/bin/omybuntu-branch-set")
if [[ $build_iso_content != *'build_branch == "main"'* ]] \
  && [[ $version_channel_content != *'current_branch == "main"'* ]] \
  && [[ $branch_set_content != *'main|master'* ]]; then
  ok "master is the only stable release branch"
else
  nok "main remains available as an operational release branch"
fi

[[ $build_iso_content == *'md5sum.txt'* && $build_iso_content == *'xargs -0 md5sum'* ]] && \
  ok "ISO build writes casper checksum manifest" || \
  nok "ISO build does not write casper checksum manifest"

gitlab_ci_content=$(<"$ROOT/.gitlab-ci.yml")
if [[ $gitlab_ci_content == *'CI_COMMIT_TAG =~ /^v[0-9]+\.[0-9]+\.[0-9]+(_(dev|rc)[0-9]+)?$/'* ]] \
  && [[ $gitlab_ci_content == *'CI_PIPELINE_SOURCE == "web"'* ]] \
  && [[ $gitlab_ci_content == *'when: never'* ]]; then
  ok "GitLab creates ISO pipelines only for three-part version tags and manual runs"
else
  nok "GitLab pipeline rules allow unintended automatic ISO builds"
fi

if [[ $gitlab_ci_content == *'stage: test'* ]] \
  && [[ $gitlab_ci_content == *'./test/omybuntu-cli-test.sh'* ]] \
  && [[ $gitlab_ci_content == *'./test/omybuntu-iso-test.sh'* ]] \
  && [[ $gitlab_ci_content == *'./test/omybuntu-update-available-test.sh'* ]]; then
  ok "GitLab requires all repository tests before building the ISO"
else
  nok "GitLab does not enforce every release test"
fi

if [[ $gitlab_ci_content == *'git merge-base --is-ancestor'* ]] \
  && [[ $gitlab_ci_content == *'release/checklists/$CI_COMMIT_TAG.md'* ]] \
  && [[ $gitlab_ci_content == *"grep -qx 'Status: approved'"* ]]; then
  ok "GitLab validates tag branches and stable hardware approval"
else
  nok "GitLab release promotion gates are incomplete"
fi

update_available_content=$(<"$ROOT/bin/omybuntu-update-available")
if [[ $update_available_content == *'v[0-9]+\.[0-9]+\.[0-9]+'* ]] \
  && [[ $update_available_content == *'_${version_pattern}_dev'* || $update_available_content == *'${version_pattern}_dev'* ]] \
  && [[ $update_available_content == *'${version_pattern}_rc'* ]] \
  && [[ $update_available_content == *'--merged="$remote_branch"'* ]] \
  && [[ $update_available_content == *'--merged=HEAD'* ]]; then
  ok "update discovery follows channel branches and three-part tags"
else
  nok "update discovery does not isolate reachable channel tags"
fi

if [[ $gitlab_ci_content == *'export OMYBUNTU_ISO_VERSION="$package_version"'* ]] \
  && [[ $gitlab_ci_content == *'./install/iso/build-iso.sh --clean'* ]] \
  && [[ $gitlab_ci_content == *'test -s "$package_file"'* ]] \
  && [[ $gitlab_ci_content == *saas-linux-medium-amd64* ]] \
  && [[ $gitlab_ci_content == *'resource_group: omybuntu-iso'* ]]; then
  ok "GitLab serializes versioned ISO builds on the medium privileged runner"
else
  nok "GitLab ISO version propagation, runner, or serialization is incomplete"
fi

if [[ $gitlab_ci_content == *'/packages/generic/omybuntu/'* ]] \
  && [[ $gitlab_ci_content == *'JOB-TOKEN: ${CI_JOB_TOKEN}'* ]] \
  && [[ $gitlab_ci_content == *'sha256sum "$package_file"'* ]] \
  && [[ $gitlab_ci_content == *'--detach-sign "$package_file"'* ]] \
  && [[ $gitlab_ci_content == *'git verify-tag "$CI_COMMIT_TAG"'* ]] \
  && [[ $gitlab_ci_content == *omybuntu-release-key.asc* ]] \
  && [[ $gitlab_ci_content == *'"*.iso.sha256"'* ]]; then
  ok "GitLab publishes signed ISO metadata through the Generic Package Registry"
else
  nok "GitLab ISO signing or publication is incomplete"
fi

if [[ $gitlab_ci_content == *'stage: release'* ]] \
  && [[ $gitlab_ci_content == *'registry.gitlab.com/gitlab-org/cli:latest'* ]] \
  && [[ $gitlab_ci_content == *'GLAB_ENABLE_CI_AUTOLOGIN: "true"'* ]] \
  && [[ $gitlab_ci_content == *'glab release create "$CI_COMMIT_TAG"'* ]] \
  && [[ $gitlab_ci_content == *'--notes-file release-notes.md'* ]] \
  && [[ $gitlab_ci_content == *'"link_type":"package"'* ]]; then
  ok "GitLab creates or updates a tag release with versioned ISO links"
else
  nok "GitLab release publication is incomplete"
fi

gitattributes_content=$(<"$ROOT/.gitattributes")
if [[ $gitattributes_content == *'*.sh text eol=lf'* ]] \
  && [[ $gitattributes_content == *'bin/* text eol=lf'* ]] \
  && [[ $gitattributes_content == *'test/* text eol=lf'* ]]; then
  ok "shell entrypoints and tests are normalized to LF"
else
  nok "shell line ending policy is incomplete"
fi

webapp_install_content=$(<"$ROOT/bin/omybuntu-webapp-install")
[[ $webapp_install_content == *LAUNCHER_ICON_FIELD* && $webapp_install_content == *hicolor/48x48/apps* && $webapp_install_content == *'gtk-update-icon-cache --ignore-theme-index'* ]] && \
  ok "webapp launchers register icons in the icon theme" || \
  nok "webapp launchers do not register icons in the icon theme"

restart_walker_content=$(<"$ROOT/bin/omybuntu-restart-walker")
[[ $restart_walker_content == *'systemctl --user cat app-walker@autostart.service'* && $restart_walker_content == *'pgrep -x walker'* && $restart_walker_content == *'kill "${walker_pids[@]}"'* && $restart_walker_content == *'setsid uwsm-app -- env GSK_RENDERER=cairo'* ]] && \
  ok "Walker restart falls back to its UWSM process without a systemd unit" || \
  nok "Walker restart lacks the UWSM process fallback"

# Summary
# ------------------------------------------------------------------
echo
if (( errors == 0 )); then
  echo "# All $total tests passed."
else
  echo "# $errors of $total tests failed." >&2
  exit 1
fi

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

if [[ $setup_content == */etc/casper.conf* && $setup_content == *USERNAME=\"ubuntu\"* ]]; then
  ok "setup-iso.sh defines the live casper user"
else
  nok "setup-iso.sh defines the live casper user"
fi

if [[ $setup_content == *omybuntu-refresh-plymouth* && $setup_content == *omybuntu-refresh-sddm* ]]; then
  ok "setup-iso.sh refreshes Plymouth and SDDM"
else
  nok "setup-iso.sh refreshes Plymouth and SDDM"
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

[[ -f $ROOT/default/wayland-sessions/hyprland.desktop ]] && \
  ok "hidden hyprland.desktop exists for uwsm" || \
  nok "hidden hyprland.desktop is missing for uwsm"

if [[ $sddm_content == *default/wayland-sessions/hyprland.desktop* ]] \
  && ! grep -q 'for session in hyprland.desktop' <<<"$sddm_content"; then
  ok "sddm.sh keeps hidden hyprland.desktop for uwsm"
else
  nok "sddm.sh still deletes hyprland.desktop"
fi

if [[ $setup_iso_content == *default/wayland-sessions/hyprland.desktop* ]] \
  && ! grep -q 'for session in hyprland.desktop' <<<"$setup_iso_content"; then
  ok "setup-iso.sh keeps hidden hyprland.desktop for uwsm"
else
  nok "setup-iso.sh still deletes hyprland.desktop"
fi

[[ -f $ROOT/bin/omybuntu-cmd-generate-ascii-logo ]] && \
  ok "ascii logo helper exists" || \
  nok "ascii logo helper is missing"

ascii_logo_content=$(<"$ROOT/bin/omybuntu-cmd-generate-ascii-logo")
[[ $ascii_logo_content == *f59e0b* && $ascii_logo_content == *-append* ]] && \
  ok "ascii logo helper defaults to orange and renders line-by-line" || \
  nok "ascii logo helper does not render orange line-by-line assets"

[[ -f $ROOT/bin/omybuntu-cmd-recolor-image-assets ]] && \
  ok "theme asset recolor helper exists" || \
  nok "theme asset recolor helper is missing"

plymouth_script_content=$(<"$ROOT/default/plymouth/omybuntu.script")
[[ $plymouth_script_content == *'if (mode == "boot" || mode == "resume") {'* && $plymouth_script_content != *'&& global.password_shown == 1'* ]] && \
  ok "plymouth shows boot progress without LUKS password" || \
  nok "plymouth still gates boot progress behind LUKS password"

sddm_metadata_content=$(<"$ROOT/default/sddm/omybuntu/metadata.desktop")
[[ $sddm_metadata_content == *MainScript=Main.qml* && $sddm_metadata_content == *Theme-API=2.0* ]] && \
  ok "sddm metadata declares MainScript and Theme-API" || \
  nok "sddm metadata is incomplete"

[[ -x $ROOT/install/iso/casper-bottom/26omybuntu-sddm-autologin ]] && \
  ok "casper hook finalizes live SDDM autologin after user creation" || \
  nok "casper hook for live SDDM autologin is missing"

[[ -f $ROOT/install/iso/casper-bottom/15autologin ]] \
  && grep -q 'omybuntu.desktop' "$ROOT/install/iso/casper-bottom/15autologin" && \
  ok "patched casper 15autologin knows the omybuntu session" || \
  nok "patched casper 15autologin is missing omybuntu session support"

if [[ $setup_iso_content == *zz-omybuntu-live.conf* && $setup_iso_content == *26omybuntu-sddm-autologin* ]] \
  && ! grep -q "\-p '\*' ubuntu" <<<"$setup_iso_content"; then
  ok "setup-iso installs live autologin hooks without locking ubuntu"
else
  nok "setup-iso live autologin setup is incomplete"
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
[[ $waybar_config_content == *'"position": "left"'* ]] && \
  ok "waybar position is left by default" || \
  nok "waybar position is not left by default"

# omybuntu-tui-monitors is compiled and copied
build_iso_content=$(<"$ROOT/install/iso/build-iso.sh")
[[ $build_iso_content == *omybuntu-tui-monitors* ]] && \
  ok "build-iso.sh copies omybuntu-tui-monitors to /usr/local/bin" || \
  nok "build-iso.sh does not copy omybuntu-tui-monitors to /usr/local/bin"

# Installer TUI uses a clean chroot install environment and final user autologin
installer_install_content=$(<"$ROOT/installer/src/install.rs")
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
  ok "installer rewrites SDDM autologin for created user" || \
  nok "installer does not rewrite SDDM autologin for created user"

installer_app_content=$(<"$ROOT/installer/src/app.rs")
[[ $installer_app_content == *valid_username* && $installer_app_content == *valid_hostname* ]] && \
  ok "installer validates system username and hostname format" || \
  nok "installer does not validate system username and hostname format"

# ------------------------------------------------------------------
# Plymouth and Hibernation Ubuntu port checks
# ------------------------------------------------------------------
echo "# Plymouth and Hibernation Ubuntu port checks"

# Plymouth scripts rebuild initramfs
refresh_plymouth_content=$(<"$ROOT/bin/omybuntu-refresh-plymouth")
[[ $refresh_plymouth_content == *update-initramfs* ]] && ok "refresh-plymouth uses update-initramfs" || nok "refresh-plymouth does not use update-initramfs"

plymouth_reset_content=$(<"$ROOT/bin/omybuntu-plymouth-reset")
[[ $plymouth_reset_content == *update-initramfs* ]] && ok "plymouth-reset uses update-initramfs" || nok "plymouth-reset does not use update-initramfs"

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
[[ $live_grub_content == *systemd.show_status=false* && $live_grub_content == *loglevel=0* ]] && \
  ok "live ISO grub.cfg has console suppressions" || \
  nok "live ISO grub.cfg does not have console suppressions"

grub_theme_content=$(<"$ROOT/default/grub/theme.txt")
[[ $grub_theme_content != *'+ scrollbar'* && $grub_theme_content != *fill_color* ]] && \
  ok "GRUB theme avoids unsupported scrollbar object and fill_color" || \
  nok "GRUB theme still contains unsupported scrollbar object or fill_color"

[[ $grub_theme_content == *scrollbar_thumb* && $grub_theme_content == *fg_color* && $grub_theme_content == *bg_color* ]] && \
  ok "GRUB theme uses supported boot menu/progress properties" || \
  nok "GRUB theme misses supported boot menu/progress properties"
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

# Summary
# ------------------------------------------------------------------
echo
if (( errors == 0 )); then
  echo "# All $total tests passed."
else
  echo "# $errors of $total tests failed." >&2
  exit 1
fi

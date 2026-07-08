use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::io::{BufRead, BufReader, Write};

// ─── Messages ─────────────────────────────────────────────────────────────────

#[derive(Debug)]
pub enum InstallMessage {
  Progress { percent: u16, message: String },
  Error(String),
  Done,
}

// ─── Config ───────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct InstallConfig {
  pub disk:          String,
  pub encrypt:       bool,
  pub luks_pass:     String,
  pub hostname:      String,
  pub username:      String,
  pub password:      String,
  pub root_password: String,
  pub language:      String,
  pub locale:        String,
  pub keymap:        String,
  pub timezone:      String,
}

const UBUNTU_CODENAME: &str = "resolute"; // 26.04
const UBUNTU_MIRROR: &str   = "http://archive.ubuntu.com/ubuntu/";

// ─── Public entry point ───────────────────────────────────────────────────────

pub fn spawn_install(config: InstallConfig) -> Receiver<InstallMessage> {
  let (tx, rx) = mpsc::channel();
  thread::spawn(move || {
    if let Err(e) = run_install(&config, &tx) {
      let _ = tx.send(InstallMessage::Error(e));
    } else {
      let _ = tx.send(InstallMessage::Done);
    }
  });
  rx
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

fn prog(tx: &Sender<InstallMessage>, percent: u16, msg: &str) {
  let _ = tx.send(InstallMessage::Progress {
    percent,
    message: msg.to_string(),
  });
}

fn cmd(args: &[&str]) -> Result<(), String> {
  let output = Command::new(args[0])
    .args(&args[1..])
    .output()
    .map_err(|e| format!("Failed to run '{}': {}", args[0], e))?;
  if !output.status.success() {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !stderr.is_empty() {
      return Err(format!("Command failed: {}\nError: {}", args.join(" "), stderr));
    } else {
      return Err(format!("Command failed: {}", args.join(" ")));
    }
  }
  Ok(())
}

fn cmd_stdin(args: &[&str], input: &[u8]) -> Result<(), String> {
  let mut child = Command::new(args[0])
    .args(&args[1..])
    .stdin(Stdio::piped())
    .stdout(Stdio::piped())
    .stderr(Stdio::piped())
    .spawn()
    .map_err(|e| format!("Failed to spawn '{}': {}", args[0], e))?;
  if let Some(mut stdin) = child.stdin.take() {
    stdin.write_all(input)
      .map_err(|e| format!("Failed to write stdin: {e}"))?;
  }
  let output = child.wait_with_output()
    .map_err(|e| format!("Failed to wait for '{}': {}", args[0], e))?;
  if !output.status.success() {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !stderr.is_empty() {
      return Err(format!("Command failed: {}\nError: {}", args.join(" "), stderr));
    } else {
      return Err(format!("Command failed: {}", args.join(" ")));
    }
  }
  Ok(())
}

fn silent_cmd(args: &[&str]) {
  let _ = Command::new(args[0])
    .args(&args[1..])
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .status();
}

fn write_file(path: &str, content: &str) -> Result<(), String> {
  std::fs::write(path, content)
    .map_err(|e| format!("Failed to write {path}: {e}"))
}

fn get_uuid(device: &str) -> Result<String, String> {
  let out = Command::new("blkid")
    .args(["-s", "UUID", "-o", "value", device])
    .output()
    .map_err(|e| format!("blkid error: {e}"))?;
  let uuid = String::from_utf8_lossy(&out.stdout).trim().to_string();
  if uuid.is_empty() {
    return Err(format!("Could not get UUID for {device}"));
  }
  Ok(uuid)
}

fn debootstrap_progress(_tx: &Sender<InstallMessage>, line: &str) -> Option<u16> {
  // debootstrap --verbose outputs lines like:
  //   I: Retrieving libc6 2.40-1ubuntu3
  //   I: Validating libc6 2.40-1ubuntu3
  //   I: Extracting libc6...
  // No built-in percentage, so we use a simple heuristic:
  // if line contains "Extracting", it's making progress
  if line.starts_with("I:") {
    if line.contains("Extracting") {
      return Some(55); // near end of debootstrap
    }
    if line.contains("Retrieving") {
      return Some(45);
    }
    if line.contains("Validating") || line.contains("Checking") {
      return Some(50);
    }
  }
  None
}

// ─── Chroot helpers ───────────────────────────────────────────────────────────

fn mount_virtual_fs(target: &str) -> Result<(), String> {
  cmd(&["mount", "--bind", "/dev",      &format!("{target}/dev")])?;
  cmd(&["mount", "--bind", "/dev/pts",  &format!("{target}/dev/pts")])?;
  cmd(&["mount", "-t", "proc", "proc",  &format!("{target}/proc")])?;
  cmd(&["mount", "-t", "sysfs", "sysfs", &format!("{target}/sys")])?;
  // Ensure resolv.conf exists so apt can resolve inside chroot
  let _ = std::fs::copy("/etc/resolv.conf", format!("{target}/etc/resolv.conf"));
  Ok(())
}

fn unmount_virtual_fs(target: &str) {
  let policy_path = format!("{target}/usr/sbin/policy-rc.d");
  let _ = std::fs::remove_file(policy_path);

  for mp in &["/sys", "/proc", "/dev/pts", "/dev"] {
    silent_cmd(&["umount", "-lf", &format!("{target}{mp}")]);
  }
}

fn write_policy_rc_d(target: &str) -> Result<(), String> {
  let path = format!("{target}/usr/sbin/policy-rc.d");
  write_file(&path, "#!/bin/sh\nexit 101\n")?;
  cmd(&["chmod", "+x", &path])?;
  Ok(())
}

struct TargetCleanup {
  target: String,
  encrypted: bool,
}

impl TargetCleanup {
  fn new(target: &str, encrypted: bool) -> Self {
    Self {
      target: target.to_string(),
      encrypted,
    }
  }
}

impl Drop for TargetCleanup {
  fn drop(&mut self) {
    unmount_virtual_fs(&self.target);
    for mp in &["/boot/efi", "/home", "/.snapshots", ""] {
      let path = format!("{}{}", self.target, mp);
      silent_cmd(&["umount", "-lf", &path]);
    }
    if self.encrypted {
      silent_cmd(&["cryptsetup", "close", "omybuntu_crypt"]);
    }
  }
}

fn write_omybuntu_apt_pins(target: &str) -> Result<(), String> {
  std::fs::create_dir_all(format!("{target}/etc/apt/preferences.d"))
    .map_err(|e| format!("Failed to create apt preferences dir: {e}"))?;
  write_file(
    &format!("{target}/etc/apt/preferences.d/99-omybuntu-desktop"),
    concat!(
      "Package: gdm3\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: gnome-session\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: ubuntu-session\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: ubuntu-desktop\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: ubuntu-desktop-minimal\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: budgie-sddm-theme\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n\n",
      "Package: sddm-theme-breeze\n",
      "Pin: release *\n",
      "Pin-Priority: -1\n",
    ),
  )
}

fn write_omybuntu_sources_list(target: &str) -> Result<(), String> {
  let content = format!(
    "deb {mirror} {codename} main restricted universe multiverse\n\
     deb {mirror} {codename}-updates main restricted universe multiverse\n\
     deb {mirror} {codename}-backports main restricted universe multiverse\n\
     deb http://security.ubuntu.com/ubuntu/ {codename}-security main restricted universe multiverse\n",
    mirror = UBUNTU_MIRROR,
    codename = UBUNTU_CODENAME
  );
  write_file(&format!("{target}/etc/apt/sources.list"), &content)
}

fn prepare_omybuntu_source_link(target: &str) -> Result<(), String> {
  std::fs::create_dir_all(format!("{target}/root/.local/share"))
    .map_err(|e| format!("Failed to create root local share: {e}"))?;
  let link = format!("{target}/root/.local/share/omybuntu");
  let _ = std::fs::remove_file(&link);
  std::os::unix::fs::symlink("/opt/omybuntu", &link)
    .map_err(|e| format!("Failed to link root Omybuntu source: {e}"))
}

fn configure_target_login(target: &str, username: &str, encrypted: bool) -> Result<(), String> {
  std::fs::create_dir_all(format!("{target}/etc/sddm.conf.d"))
    .map_err(|e| format!("Failed to create sddm.conf.d: {e}"))?;
  let autologin_block = if encrypted {
    format!(
      "[Autologin]\n\
User={username}\n\
Session=omybuntu\n\
Relogin=true\n\n",
    )
  } else {
    String::new()
  };
  write_file(
    &format!("{target}/etc/sddm.conf.d/99-omybuntu.conf"),
    &format!(
      "[General]\n\
DisplayServer=wayland\n\
DefaultSession=omybuntu\n\n\
[Wayland]\n\
CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.conf\n\n\
{autologin_block}\
[Theme]\n\
Current=omybuntu\n",
    ),
  )?;

  std::fs::create_dir_all(format!("{target}/etc/systemd/system/graphical.target.wants"))
    .map_err(|e| format!("Failed to create graphical target wants dir: {e}"))?;
  let display_manager = format!("{target}/etc/systemd/system/display-manager.service");
  let graphical_want = format!("{target}/etc/systemd/system/graphical.target.wants/sddm.service");
  let default_target = format!("{target}/etc/systemd/system/default.target");
  let _ = std::fs::remove_file(&display_manager);
  let _ = std::fs::remove_file(&graphical_want);
  let _ = std::fs::remove_file(&default_target);

  let sddm_unit = if std::path::Path::new(&format!("{target}/usr/lib/systemd/system/sddm.service")).exists() {
    "/usr/lib/systemd/system/sddm.service"
  } else {
    "/lib/systemd/system/sddm.service"
  };
  std::os::unix::fs::symlink(sddm_unit, &display_manager)
    .map_err(|e| format!("Failed to link display-manager.service: {e}"))?;
  std::os::unix::fs::symlink(sddm_unit, &graphical_want)
    .map_err(|e| format!("Failed to link sddm.service into graphical target: {e}"))?;

  let graphical_target = if std::path::Path::new(&format!("{target}/usr/lib/systemd/system/graphical.target")).exists() {
    "/usr/lib/systemd/system/graphical.target"
  } else {
    "/lib/systemd/system/graphical.target"
  };
  std::os::unix::fs::symlink(graphical_target, &default_target)
    .map_err(|e| format!("Failed to set graphical.target as default: {e}"))?;

  Ok(())
}

fn clean_disk_mounts(disk: &str) -> Result<(), String> {
  // 0. Deactivate LVM volume groups to avoid locked partitions
  silent_cmd(&["vgchange", "-an"]);

  // 1. Run swapoff on any partition of the disk
  if let Ok(file) = std::fs::File::open("/proc/swaps") {
    let reader = BufReader::new(file);
    for line in reader.lines().map_while(Result::ok) {
      let parts: Vec<&str> = line.split_whitespace().collect();
      if !parts.is_empty() && (parts[0].starts_with(disk) || parts[0] == disk) {
        silent_cmd(&["swapoff", parts[0]]);
      }
    }
  }

  // 2. Find and unmount any mounted partitions of the disk from /proc/mounts
  let mut mounts = Vec::new();
  if let Ok(file) = std::fs::File::open("/proc/mounts") {
    let reader = BufReader::new(file);
    for line in reader.lines().map_while(Result::ok) {
      let parts: Vec<&str> = line.split_whitespace().collect();
      if parts.len() >= 2 && (parts[0].starts_with(disk) || parts[0] == disk) {
        mounts.push((parts[0].to_string(), parts[1].to_string()));
      }
    }
  }
  // Sort mounts by mount point path length descending to unmount nested mounts first
  mounts.sort_by(|a, b| b.1.len().cmp(&a.1.len()));
  for (_, mp) in &mounts {
    silent_cmd(&["umount", "-lf", mp]);
  }

  // 3. Check for any holder device mapper (LUKS) mappings.
  if let Ok(entries) = std::fs::read_dir("/sys/class/block") {
    for entry in entries.map_while(Result::ok) {
      let name = entry.file_name().to_string_lossy().into_owned();
      let disk_leaf = disk.trim_start_matches("/dev/");
      if name.starts_with(disk_leaf) {
        let holders_path = format!("/sys/class/block/{}/holders", name);
        if let Ok(holders) = std::fs::read_dir(&holders_path) {
          for holder in holders.map_while(Result::ok) {
            let dm_name = holder.file_name().to_string_lossy().into_owned();
            let crypt_name_path = format!("/sys/class/block/{}/dm/name", dm_name);
            if let Ok(crypt_name) = std::fs::read_to_string(&crypt_name_path) {
              let crypt_name = crypt_name.trim();
              if !crypt_name.is_empty() {
                silent_cmd(&["cryptsetup", "close", crypt_name]);
              }
            }
          }
        }
      }
    }
  }

  Ok(())
}

fn run_diagnostic_commands(disk: &str) -> Result<(), String> {
  eprintln!("=== INSTALLER DIAGNOSTICS ===");
  eprintln!("Disk: {}", disk);
  
  let lsblk_out = Command::new("lsblk").args(["-o", "NAME,FSTYPE,SIZE,MOUNTPOINTS", disk]).output();
  match lsblk_out {
    Ok(out) => {
      eprintln!("lsblk output:\n{}", String::from_utf8_lossy(&out.stdout));
      eprintln!("lsblk stderr:\n{}", String::from_utf8_lossy(&out.stderr));
    }
    Err(e) => eprintln!("Failed to run lsblk: {}", e),
  }

  let findmnt_out = Command::new("findmnt").output();
  match findmnt_out {
    Ok(out) => {
      eprintln!("findmnt output (filtered for disk):\n{}", 
        String::from_utf8_lossy(&out.stdout)
          .lines()
          .filter(|l| l.contains(disk) || l.contains("mapper"))
          .collect::<Vec<_>>()
          .join("\n")
      );
    }
    Err(e) => eprintln!("Failed to run findmnt: {}", e),
  }

  let dm_out = Command::new("dmsetup").arg("ls").output();
  match dm_out {
    Ok(out) => {
      eprintln!("dmsetup ls output:\n{}", String::from_utf8_lossy(&out.stdout));
    }
    Err(e) => eprintln!("Failed to run dmsetup ls: {}", e),
  }

  eprintln!("=============================");
  Ok(())
}

// ─── Installation ─────────────────────────────────────────────────────────────

fn run_install(cfg: &InstallConfig, tx: &Sender<InstallMessage>) -> Result<(), String> {
  let suffix = if cfg.disk.contains("nvme") || cfg.disk.contains("mmcblk") { "p" } else { "" };
  let part_efi  = format!("{}{suffix}1", cfg.disk);
  let part_root = format!("{}{suffix}2", cfg.disk);

  let target = "/mnt";

  // ── 1. Partition ──────────────────────────────────────────────────────────
  prog(tx, 5, "Partitioning disk...");
  if let Err(e) = clean_disk_mounts(&cfg.disk) {
    eprintln!("Warning while cleaning disk mounts: {}", e);
  }

  // Attempt to zap-all, with fallback and logging
  if let Err(e) = cmd(&["sgdisk", "--zap-all", &cfg.disk]) {
    eprintln!("Initial sgdisk --zap-all failed: {}. Running diagnostics...", e);
    let _ = run_diagnostic_commands(&cfg.disk);

    // Try a quick dd fallback to wipe the partition headers (first 10MB)
    eprintln!("Trying to wipe partition headers with dd...");
    let dd_res = Command::new("dd")
      .args(["if=/dev/zero", &format!("of={}", cfg.disk), "bs=1M", "count=10", "oflag=direct"])
      .stdout(Stdio::null())
      .stderr(Stdio::null())
      .status();
    if let Err(ref dd_err) = dd_res {
      eprintln!("dd fallback failed: {}", dd_err);
    }
    
    // Rerun partprobe
    silent_cmd(&["partprobe", &cfg.disk]);
    std::thread::sleep(std::time::Duration::from_millis(500));

    // Try sgdisk --zap-all again
    eprintln!("Retrying sgdisk --zap-all after dd...");
    if let Err(retry_err) = cmd(&["sgdisk", "--zap-all", &cfg.disk]) {
      eprintln!("sgdisk --zap-all failed again: {}. Trying parted label creation as a fallback...", retry_err);
      cmd(&["parted", "-s", &cfg.disk, "mklabel", "gpt"])
        .map_err(|final_err| format!("Partitioning failed. sgdisk and parted both failed. Parted error: {}", final_err))?;
    }
  }
  cmd(&[
    "sgdisk",
    "-n", "1:0:+512M", "-t", "1:ef00",
    "-n", "2:0:0",     "-t", "2:8300",
    &cfg.disk,
  ])?;
  silent_cmd(&["partprobe", &cfg.disk]);
  std::thread::sleep(std::time::Duration::from_secs(1));

  // ── 2. Format EFI ─────────────────────────────────────────────────────────
  prog(tx, 10, "Formatting EFI partition...");
  cmd(&["mkfs.vfat", "-F32", &part_efi])?;

  // ── 3. LUKS or direct ─────────────────────────────────────────────────────
  let root_dev = if cfg.encrypt {
    prog(tx, 15, "Setting up LUKS encryption...");
    cmd_stdin(
      &["cryptsetup", "luksFormat", "--batch-mode", &part_root, "--key-file=-"],
      cfg.luks_pass.as_bytes(),
    )?;
    prog(tx, 20, "Opening encrypted volume...");
    cmd_stdin(
      &["cryptsetup", "open", &part_root, "omybuntu_crypt", "--key-file=-"],
      cfg.luks_pass.as_bytes(),
    )?;
    "/dev/mapper/omybuntu_crypt".to_string()
  } else {
    part_root.clone()
  };

  // ── 4. Format BTRFS ───────────────────────────────────────────────────────
  prog(tx, 25, "Formatting root partition as BTRFS...");
  cmd(&["mkfs.btrfs", "-f", &root_dev])?;

  // ── 5. BTRFS subvolumes ───────────────────────────────────────────────────
  prog(tx, 30, "Creating BTRFS subvolumes (@, @home, @snapshots)...");
  cmd(&["mount", &root_dev, target])?;
  cmd(&["btrfs", "subvolume", "create", &format!("{target}/@")])?;
  cmd(&["btrfs", "subvolume", "create", &format!("{target}/@home")])?;
  cmd(&["btrfs", "subvolume", "create", &format!("{target}/@snapshots")])?;
  cmd(&["umount", target])?;

  // ── 6. Mount target layout ────────────────────────────────────────────────
  prog(tx, 35, "Mounting BTRFS subvolumes...");
  cmd(&["mount", "-o", "subvol=@,noatime,compress=zstd",      &root_dev, target])?;
  cmd(&["mkdir", "-p", &format!("{target}/home"),
                     &format!("{target}/boot/efi"),
                     &format!("{target}/.snapshots")])?;
  cmd(&["mount", "-o", "subvol=@home,noatime,compress=zstd",     &root_dev, &format!("{target}/home")])?;
  cmd(&["mount", "-o", "subvol=@snapshots,noatime,compress=zstd",&root_dev, &format!("{target}/.snapshots")])?;
  cmd(&["mount", &part_efi, &format!("{target}/boot/efi")])?;
  let _target_cleanup = TargetCleanup::new(target, cfg.encrypt);

  // ── 7. Debootstrap Ubuntu base ────────────────────────────────────────────
  prog(tx, 40, "Installing Ubuntu base system via debootstrap...");
  let mut debootstrap = Command::new("debootstrap")
    .args(["--arch=amd64", "--verbose", UBUNTU_CODENAME, target, UBUNTU_MIRROR])
    .stdout(Stdio::piped())
    .stderr(Stdio::null())
    .spawn()
    .map_err(|e| format!("debootstrap: {e}"))?;

  if let Some(stdout) = debootstrap.stdout.take() {
    let reader = BufReader::new(stdout);
    for line in reader.lines().map_while(Result::ok) {
      if let Some(pct) = debootstrap_progress(tx, &line) {
        let label = line.trim().trim_start_matches("I: ").to_string();
        prog(tx, pct, if label.is_empty() { "Debootstrap in progress..." } else { &label });
      }
    }
  }
  let status = debootstrap.wait().map_err(|e| format!("debootstrap wait: {e}"))?;
  if !status.success() {
    return Err("debootstrap failed — check network mirror and target disk".into());
  }

  write_omybuntu_sources_list(target)?;

  // ── 8. Copy Omybuntu codebase to target ───────────────────────────────────
  prog(tx, 58, "Copying Omybuntu to target system...");
  cmd(&["mkdir", "-p", &format!("{target}/opt/omybuntu")])?;
  let output = Command::new("rsync")
    .args([
      "-a", "--delete",
      "--exclude=build/",
      "--exclude=.git/",
      "--exclude=installer/target/",
      "--exclude=*.iso",
      "--exclude=.iso-cache/",
      "--exclude=ubuntu-base.tar.gz",
      "/opt/omybuntu/",
      &format!("{target}/opt/omybuntu/"),
    ])
    .output()
    .map_err(|e| format!("rsync copy omybuntu: {e}"))?;
  if !output.status.success() {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !stderr.is_empty() {
      return Err(format!("Failed to copy Omybuntu to target: {}", stderr));
    } else {
      return Err("Failed to copy Omybuntu to target".into());
    }
  }
  prepare_omybuntu_source_link(target)?;
  write_omybuntu_apt_pins(target)?;

  // ── 9. Mount virtual filesystems for chroot ───────────────────────────────
  prog(tx, 60, "Mounting virtual filesystems for chroot...");
  mount_virtual_fs(target)?;
  write_policy_rc_d(target)?;

  prog(tx, 61, "Installing bootstrap packages inside chroot...");
  cmd(&[
    "chroot", target, "env", "DEBIAN_FRONTEND=noninteractive",
    "apt-get", "update"
  ])?;
  cmd(&[
    "chroot", target, "env", "DEBIAN_FRONTEND=noninteractive",
    "apt-get", "install", "-y", "curl", "gpg", "ca-certificates", "sudo", "software-properties-common", "git", "wget", "gum"
  ])?;

  // ── 10. Generate fstab ───────────────────────────────────────────────────
  prog(tx, 62, "Generating /etc/fstab...");
  let uuid_root = get_uuid(&root_dev)?;
  let uuid_efi  = get_uuid(&part_efi)?;
  let fstab_path = format!("{target}/etc/fstab");
  write_file(
    &fstab_path,
    &format!(
      "UUID={uuid_root}  /            btrfs  subvol=@,defaults,noatime,compress=zstd           0 1\n\
       UUID={uuid_root}  /home        btrfs  subvol=@home,defaults,noatime,compress=zstd       0 2\n\
       UUID={uuid_root}  /.snapshots  btrfs  subvol=@snapshots,defaults,noatime,compress=zstd  0 2\n\
       UUID={uuid_efi}   /boot/efi    vfat   defaults,noatime                                   0 2\n",
    ),
  )?;

  // ── 11. crypttab ──────────────────────────────────────────────────────────
  if cfg.encrypt {
    prog(tx, 64, "Generating /etc/crypttab...");
    let uuid_luks = get_uuid(&part_root)?;
    write_file(
      &format!("{target}/etc/crypttab"),
      &format!("omybuntu_crypt UUID={uuid_luks} none luks,discard\n"),
    )?;
  }

  // ── 12. Hostname + hosts ──────────────────────────────────────────────────
  prog(tx, 66, "Configuring hostname...");
  write_file(&format!("{target}/etc/hostname"), &format!("{}\n", cfg.hostname))?;
  write_file(
    &format!("{target}/etc/hosts"),
    &format!(
      "127.0.0.1\tlocalhost\n127.0.1.1\t{}\n::1\tlocalhost ip6-localhost ip6-loopback\n",
      cfg.hostname,
    ),
  )?;

  // ── 13. Locale + keyboard ─────────────────────────────────────────────────
  prog(tx, 68, "Configuring locale and keyboard layout...");
  write_file(
    &format!("{target}/etc/default/locale"),
    &format!("LANG=\"{}\"\nLANGUAGE=\"{}\"\n", cfg.locale, cfg.locale),
  )?;
  write_file(
    &format!("{target}/etc/default/keyboard"),
    &format!("XKBLAYOUT={}\nXKBMODEL=pc105\n", cfg.keymap),
  )?;

  // Generate locale
  let _ = Command::new("chroot")
    .args([target, "locale-gen", &cfg.locale])
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .status();

  // ── 14. Timezone ──────────────────────────────────────────────────────────
  prog(tx, 70, "Setting timezone...");
  cmd(&[
    "chroot", target, "ln", "-sf",
    &format!("/usr/share/zoneinfo/{}", cfg.timezone),
    "/etc/localtime",
  ])?;

  // ── 15. Run Omybuntu install.sh inside chroot ────────────────────────────
  prog(tx, 72, "Configuring Omybuntu system (install.sh)...");
  let target_user_env = format!("OMYBUNTU_TARGET_USER={}", cfg.username);
  let language_env = format!("OMYBUNTU_LANGUAGE={}", cfg.language);
  let encrypted_install_env = if cfg.encrypt {
    "OMYBUNTU_ENCRYPTED_INSTALL=true"
  } else {
    "OMYBUNTU_ENCRYPTED_INSTALL=false"
  };
  let status = Command::new("chroot")
    .arg(target)
    .arg("/usr/bin/env")
    .arg("-i")
    .args([
      "HOME=/root",
      "USER=root",
      "LOGNAME=root",
      "SHELL=/bin/bash",
      "TERM=linux",
      "PATH=/opt/omybuntu/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "OMYBUNTU_PATH=/opt/omybuntu",
      "OMYBUNTU_INSTALL=/opt/omybuntu/install",
      "OMYBUNTU_INSTALL_LOG_FILE=/var/log/omybuntu-install.log",
      "OMYBUNTU_ONLINE_INSTALL=true",
      "OMYBUNTU_CHROOT_INSTALL=true",
      encrypted_install_env,
      "DEBIAN_FRONTEND=noninteractive",
    ])
    .arg(&language_env)
    .arg(target_user_env)
    .args([
      "/bin/bash", "-e", "-c",
      "cd /opt/omybuntu && ./install.sh",
    ])
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .status()
    .map_err(|e| format!("chroot install.sh: {e}"))?;
  if !status.success() {
    return Err("Omybuntu install.sh failed inside chroot".into());
  }

  // ── 16. Create user account ──────────────────────────────────────────────
  prog(tx, 84, "Creating user account...");
  cmd(&["chroot", target, "groupadd", "-f", "sudo"])?;
  cmd(&["chroot", target, "useradd", "-m", "-s", "/bin/bash", &cfg.username])?;
  for group in &["sudo", "audio", "video", "users", "input", "render", "docker"] {
    let status = Command::new("chroot")
      .args([target, "getent", "group", group])
      .stdout(Stdio::null())
      .stderr(Stdio::null())
      .status()
      .map_err(|e| format!("Failed to check group {group}: {e}"))?;
    if status.success() {
      cmd(&["chroot", target, "usermod", "-aG", group, &cfg.username])?;
    }
  }

  cmd_stdin(
    &["chroot", target, "chpasswd"],
    format!("{}:{}\n", cfg.username, cfg.password).as_bytes(),
  )?;
  cmd_stdin(
    &["chroot", target, "chpasswd"],
    format!("root:{}\n", cfg.root_password).as_bytes(),
  )?;

  // ── 17. Omybuntu language preference ─────────────────────────────────────
  prog(tx, 86, "Saving language preference...");
  let cfg_dir = format!("{target}/home/{}/.config/omybuntu", cfg.username);
  std::fs::create_dir_all(&cfg_dir).ok();
  write_file(&format!("{cfg_dir}/language"), &cfg.language)?;
  let _ = Command::new("chroot")
    .args([target, "chown", "-R",
      &format!("{}:{}", cfg.username, cfg.username),
      &format!("/home/{}", cfg.username),
    ])
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .status();
  configure_target_login(target, &cfg.username, cfg.encrypt)?;

  // ── 18. GRUB ─────────────────────────────────────────────────────────────
  prog(tx, 88, "Installing GRUB bootloader...");
  if cfg.encrypt {
    let grub_default = std::fs::read_to_string(format!("{target}/etc/default/grub")).unwrap_or_default();
    if !grub_default.contains("GRUB_ENABLE_CRYPTODISK") {
      write_file(
        &format!("{target}/etc/default/grub"),
        &format!("{grub_default}\nGRUB_ENABLE_CRYPTODISK=y\n"),
      )?;
    }
  }
  cmd(&[
    "chroot", target, "grub-install",
    "--target=x86_64-efi",
    "--efi-directory=/boot/efi",
    "--bootloader-id=Omybuntu",
    "--recheck",
  ])?;

  prog(tx, 91, "Applying GRUB theme in selected language...");
  let refresh_grub = format!(
    "OMYBUNTU_LANGUAGE={} OMYBUNTU_PATH=/opt/omybuntu /opt/omybuntu/bin/omybuntu-refresh-grub",
    cfg.language,
  );
  cmd(&["chroot", target, "bash", "-c", &refresh_grub])?;

  // ── 19. initramfs ─────────────────────────────────────────────────────────
  prog(tx, 96, "Updating initramfs...");
  cmd(&["chroot", target, "update-initramfs", "-u", "-k", "all"])?;

  // ── 20. Unmount ───────────────────────────────────────────────────────────
  prog(tx, 98, "Unmounting filesystems...");
  // Unmount virtual filesystems first (chroot must not be busy)
  unmount_virtual_fs(target);
  for mp in &["/boot/efi", "/home", "/.snapshots", ""] {
    let path = format!("{target}{mp}");
    silent_cmd(&["umount", "-lf", &path]);
  }
  if cfg.encrypt {
    silent_cmd(&["cryptsetup", "close", "omybuntu_crypt"]);
  }

  prog(tx, 100, "Installation complete!");
  Ok(())
}

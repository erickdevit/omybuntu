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
  let status = Command::new(args[0])
    .args(&args[1..])
    .status()
    .map_err(|e| format!("Failed to run '{}': {}", args[0], e))?;
  if !status.success() {
    return Err(format!("Command failed: {}", args.join(" ")));
  }
  Ok(())
}

fn cmd_stdin(args: &[&str], input: &[u8]) -> Result<(), String> {
  let mut child = Command::new(args[0])
    .args(&args[1..])
    .stdin(Stdio::piped())
    .spawn()
    .map_err(|e| format!("Failed to spawn '{}': {}", args[0], e))?;
  if let Some(stdin) = child.stdin.as_mut() {
    stdin.write_all(input)
      .map_err(|e| format!("Failed to write stdin: {e}"))?;
  }
  let status = child.wait()
    .map_err(|e| format!("Failed to wait for '{}': {}", args[0], e))?;
  if !status.success() {
    return Err(format!("Command failed: {}", args.join(" ")));
  }
  Ok(())
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
  for mp in &["/sys", "/proc", "/dev/pts", "/dev"] {
    let _ = Command::new("umount").args(["-lf", &format!("{target}{mp}")]).status();
  }
}

// ─── Installation ─────────────────────────────────────────────────────────────

fn run_install(cfg: &InstallConfig, tx: &Sender<InstallMessage>) -> Result<(), String> {
  let suffix = if cfg.disk.contains("nvme") || cfg.disk.contains("mmcblk") { "p" } else { "" };
  let part_efi  = format!("{}{suffix}1", cfg.disk);
  let part_root = format!("{}{suffix}2", cfg.disk);

  let target = "/mnt";

  // ── 1. Partition ──────────────────────────────────────────────────────────
  prog(tx, 5, "Partitioning disk...");
  cmd(&["sgdisk", "--zap-all", &cfg.disk])?;
  cmd(&[
    "sgdisk",
    "-n", "1:0:+512M", "-t", "1:ef00",
    "-n", "2:0:0",     "-t", "2:8300",
    &cfg.disk,
  ])?;
  Command::new("partprobe").arg(&cfg.disk).status().ok();
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

  // ── 7. Debootstrap Ubuntu base ────────────────────────────────────────────
  prog(tx, 40, "Installing Ubuntu base system via debootstrap...");
  let mut debootstrap = Command::new("debootstrap")
    .args(["--arch=amd64", "--verbose", UBUNTU_CODENAME, target, UBUNTU_MIRROR])
    .stdout(Stdio::piped())
    .stderr(Stdio::inherit())
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

  // ── 8. Copy Omybuntu codebase to target ───────────────────────────────────
  prog(tx, 58, "Copying Omybuntu to target system...");
  cmd(&["mkdir", "-p", &format!("{target}/opt/omybuntu")])?;
  let status = Command::new("rsync")
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
    .status()
    .map_err(|e| format!("rsync copy omybuntu: {e}"))?;
  if !status.success() {
    return Err("Failed to copy Omybuntu to target".into());
  }

  // ── 9. Mount virtual filesystems for chroot ───────────────────────────────
  prog(tx, 60, "Mounting virtual filesystems for chroot...");
  mount_virtual_fs(target)?;

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
  Command::new("chroot")
    .args([target, "locale-gen", &cfg.locale])
    .status().ok();

  // ── 14. Timezone ──────────────────────────────────────────────────────────
  prog(tx, 70, "Setting timezone...");
  cmd(&[
    "chroot", target, "ln", "-sf",
    &format!("/usr/share/zoneinfo/{}", cfg.timezone),
    "/etc/localtime",
  ])?;

  // ── 15. Run Omybuntu install.sh inside chroot ────────────────────────────
  prog(tx, 72, "Configuring Omybuntu system (install.sh)...");
  let status = Command::new("chroot")
    .args([target, "env",
      "OMYBUNTU_ISO_BUILD=true",
      "OMYBUNTU_CHROOT_INSTALL=true",
      "DEBIAN_FRONTEND=noninteractive",
      "/bin/bash", "-c",
      "cd /opt/omybuntu && ./install.sh",
    ])
    .status()
    .map_err(|e| format!("chroot install.sh: {e}"))?;
  if !status.success() {
    return Err("Omybuntu install.sh failed inside chroot".into());
  }

  // ── 16. Create user account ──────────────────────────────────────────────
  prog(tx, 84, "Creating user account...");
  Command::new("chroot")
    .args([target, "groupadd", "-f", "sudo"])
    .status().ok();
  Command::new("chroot")
    .args([target, "useradd", "-m", "-G", "sudo,audio,video,users", "-s", "/bin/bash", &cfg.username])
    .status().ok();

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
  Command::new("chroot")
    .args([target, "chown", "-R",
      &format!("{}:{}", cfg.username, cfg.username),
      &format!("/home/{}/.config", cfg.username),
    ])
    .status().ok();

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

  prog(tx, 93, "Generating grub.cfg...");
  cmd(&["chroot", target, "grub-mkconfig", "-o", "/boot/grub/grub.cfg"])?;

  // ── 19. initramfs ─────────────────────────────────────────────────────────
  prog(tx, 96, "Updating initramfs...");
  cmd(&["chroot", target, "update-initramfs", "-u", "-k", "all"])?;

  // ── 20. Unmount ───────────────────────────────────────────────────────────
  prog(tx, 98, "Unmounting filesystems...");
  // Unmount virtual filesystems first (chroot must not be busy)
  unmount_virtual_fs(target);
  for mp in &["/boot/efi", "/home", "/.snapshots", ""] {
    let path = format!("{target}{mp}");
    let _ = Command::new("umount").args(["-lf", &path]).status();
  }
  if cfg.encrypt {
    Command::new("cryptsetup").args(["close", "omybuntu_crypt"]).status().ok();
  }

  prog(tx, 100, "Installation complete!");
  Ok(())
}

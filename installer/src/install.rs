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

fn parse_rsync_percent(line: &str) -> Option<u16> {
    for part in line.trim().split_whitespace() {
        if part.ends_with('%') {
            if let Ok(n) = part.trim_end_matches('%').parse::<u16>() {
                return Some(n.min(100));
            }
        }
    }
    None
}

// ─── Installation ─────────────────────────────────────────────────────────────

fn run_install(cfg: &InstallConfig, tx: &Sender<InstallMessage>) -> Result<(), String> {
    // Determine partition naming (nvme/mmcblk use 'p' suffix)
    let suffix = if cfg.disk.contains("nvme") || cfg.disk.contains("mmcblk") { "p" } else { "" };
    let part_efi  = format!("{}{suffix}1", cfg.disk);
    let part_root = format!("{}{suffix}2", cfg.disk);

    // ── 1. Partition ──────────────────────────────────────────────────────────
    prog(tx, 5, "Partitioning disk...");
    cmd(&["sgdisk", "--zap-all", &cfg.disk])?;
    cmd(&[
        "sgdisk",
        "-n", "1:0:+512M", "-t", "1:ef00",
        "-n", "2:0:0",     "-t", "2:8300",
        &cfg.disk,
    ])?;
    // Allow kernel to re-read partition table
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
    cmd(&["mount", &root_dev, "/mnt"])?;
    cmd(&["btrfs", "subvolume", "create", "/mnt/@"])?;
    cmd(&["btrfs", "subvolume", "create", "/mnt/@home"])?;
    cmd(&["btrfs", "subvolume", "create", "/mnt/@snapshots"])?;
    cmd(&["umount", "/mnt"])?;

    // ── 6. Mount target layout ────────────────────────────────────────────────
    prog(tx, 35, "Mounting BTRFS subvolumes...");
    cmd(&["mount", "-o", "subvol=@,noatime,compress=zstd", &root_dev, "/mnt"])?;
    cmd(&["mkdir", "-p", "/mnt/home", "/mnt/boot/efi", "/mnt/.snapshots"])?;
    cmd(&["mount", "-o", "subvol=@home,noatime,compress=zstd",      &root_dev, "/mnt/home"])?;
    cmd(&["mount", "-o", "subvol=@snapshots,noatime,compress=zstd", &root_dev, "/mnt/.snapshots"])?;
    cmd(&["mount", &part_efi, "/mnt/boot/efi"])?;

    // ── 7. Rsync ──────────────────────────────────────────────────────────────
    prog(tx, 40, "Copying system files to target disk (this may take a while)...");
    let mut rsync = Command::new("rsync")
        .args([
            "-aAX",
            "--info=progress2",
            "--exclude=/dev/*",
            "--exclude=/proc/*",
            "--exclude=/sys/*",
            "--exclude=/tmp/*",
            "--exclude=/run/*",
            "--exclude=/mnt/*",
            "--exclude=/media/*",
            "--exclude=/lost+found",
            "/", "/mnt/",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("rsync: {e}"))?;

    if let Some(stdout) = rsync.stdout.take() {
        let reader = BufReader::new(stdout);
        let mut last: u16 = 40;
        for line in reader.lines().map_while(Result::ok) {
            if let Some(pct) = parse_rsync_percent(&line) {
                // Map rsync 0-100% to overall 40-72%
                let overall = 40 + pct * 32 / 100;
                if overall > last {
                    last = overall;
                    prog(tx, overall, &format!("Copying files... {pct}%"));
                }
            }
        }
    }
    rsync.wait().map_err(|e| format!("rsync wait: {e}"))?;

    // ── 8. fstab ──────────────────────────────────────────────────────────────
    prog(tx, 74, "Generating /etc/fstab...");
    let uuid_root = get_uuid(&root_dev)?;
    let uuid_efi  = get_uuid(&part_efi)?;
    write_file(
        "/mnt/etc/fstab",
        &format!(
            "UUID={uuid_root}  /            btrfs  subvol=@,defaults,noatime,compress=zstd           0 1\n\
             UUID={uuid_root}  /home        btrfs  subvol=@home,defaults,noatime,compress=zstd       0 2\n\
             UUID={uuid_root}  /.snapshots  btrfs  subvol=@snapshots,defaults,noatime,compress=zstd  0 2\n\
             UUID={uuid_efi}   /boot/efi    vfat   defaults,noatime                                   0 2\n",
        ),
    )?;

    // ── 9. crypttab ───────────────────────────────────────────────────────────
    if cfg.encrypt {
        prog(tx, 76, "Generating /etc/crypttab...");
        let uuid_luks = get_uuid(&part_root)?;
        write_file(
            "/mnt/etc/crypttab",
            &format!("omybuntu_crypt UUID={uuid_luks} none luks,discard\n"),
        )?;
    }

    // ── 10. Hostname + hosts ──────────────────────────────────────────────────
    prog(tx, 78, "Configuring hostname...");
    write_file("/mnt/etc/hostname", &format!("{}\n", cfg.hostname))?;
    write_file(
        "/mnt/etc/hosts",
        &format!(
            "127.0.0.1\tlocalhost\n127.0.1.1\t{}\n::1\tlocalhost ip6-localhost ip6-loopback\n",
            cfg.hostname,
        ),
    )?;

    // ── 11. Locale + keyboard ─────────────────────────────────────────────────
    prog(tx, 80, "Configuring locale and keyboard layout...");
    write_file(
        "/mnt/etc/default/locale",
        &format!("LANG=\"{}\"\nLANGUAGE=\"{}\"\n", cfg.locale, cfg.locale),
    )?;
    write_file(
        "/mnt/etc/default/keyboard",
        &format!("XKBLAYOUT={}\nXKBMODEL=pc105\n", cfg.keymap),
    )?;

    // ── 12. Timezone ──────────────────────────────────────────────────────────
    prog(tx, 82, "Setting timezone...");
    cmd(&[
        "chroot", "/mnt", "ln", "-sf",
        &format!("/usr/share/zoneinfo/{}", cfg.timezone),
        "/etc/localtime",
    ])?;

    // ── 13. User accounts ─────────────────────────────────────────────────────
    prog(tx, 84, "Creating user account...");
    Command::new("chroot")
        .args(["/mnt", "useradd", "-m", "-G", "sudo,audio,video,users", "-s", "/bin/bash", &cfg.username])
        .status().ok(); // Non-fatal: user might already exist in live system

    cmd_stdin(
        &["chroot", "/mnt", "chpasswd"],
        format!("{}:{}\n", cfg.username, cfg.password).as_bytes(),
    )?;
    cmd_stdin(
        &["chroot", "/mnt", "chpasswd"],
        format!("root:{}\n", cfg.root_password).as_bytes(),
    )?;

    // ── 14. Omybuntu language preference ──────────────────────────────────────
    prog(tx, 86, "Saving language preference...");
    let cfg_dir = format!("/mnt/home/{}/.config/omybuntu", cfg.username);
    std::fs::create_dir_all(&cfg_dir).ok();
    write_file(&format!("{cfg_dir}/language"), &cfg.language)?;
    Command::new("chroot")
        .args([
            "/mnt", "chown", "-R",
            &format!("{}:{}", cfg.username, cfg.username),
            &format!("/home/{}/.config", cfg.username),
        ])
        .status().ok();

    // ── 15. GRUB ──────────────────────────────────────────────────────────────
    prog(tx, 88, "Installing GRUB bootloader...");
    if cfg.encrypt {
        let grub_default = std::fs::read_to_string("/mnt/etc/default/grub").unwrap_or_default();
        if !grub_default.contains("GRUB_ENABLE_CRYPTODISK") {
            write_file("/mnt/etc/default/grub", &format!("{grub_default}\nGRUB_ENABLE_CRYPTODISK=y\n"))?;
        }
    }
    cmd(&[
        "chroot", "/mnt", "grub-install",
        "--target=x86_64-efi",
        "--efi-directory=/boot/efi",
        "--bootloader-id=Omybuntu",
        "--recheck",
    ])?;

    prog(tx, 92, "Generating grub.cfg...");
    cmd(&["chroot", "/mnt", "grub-mkconfig", "-o", "/boot/grub/grub.cfg"])?;

    // ── 16. initramfs ─────────────────────────────────────────────────────────
    prog(tx, 95, "Updating initramfs (encrypt + BTRFS modules)...");
    cmd(&["chroot", "/mnt", "update-initramfs", "-u", "-k", "all"])?;

    // ── 17. Unmount ───────────────────────────────────────────────────────────
    prog(tx, 98, "Unmounting filesystems...");
    for mp in &["/mnt/boot/efi", "/mnt/home", "/mnt/.snapshots", "/mnt"] {
        Command::new("umount").args(["-lf", mp]).status().ok();
    }
    if cfg.encrypt {
        Command::new("cryptsetup").args(["close", "omybuntu_crypt"]).status().ok();
    }

    prog(tx, 100, "Installation complete!");
    Ok(())
}

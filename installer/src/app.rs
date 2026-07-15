use std::sync::mpsc::Receiver;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use crate::install::{InstallConfig, InstallMessage, spawn_install};
use crate::storage::{
    AlongsideCandidate, DiskInfo, StorageMode, StoragePlan,
    detect_disks, discover_alongside_candidates, is_secure_boot_enabled,
};

// ─── Constants ────────────────────────────────────────────────────────────────

pub const LANGUAGES: &[(&str, &str, &str)] = &[
    ("English",            "en",    "en_US.UTF-8"),
    ("Português (Brasil)", "pt-br", "pt_BR.UTF-8"),
    ("Español",            "es",    "es_ES.UTF-8"),
];

pub const KEYBOARDS: &[(&str, &str)] = &[
    ("us  — English (US)",         "us"),
    ("br  — Português (Brasil)",   "br"),
    ("es  — Español",              "es"),
    ("de  — Deutsch",              "de"),
    ("fr  — Français",             "fr"),
    ("it  — Italiano",             "it"),
    ("pt  — Português (Portugal)", "pt"),
    ("gb  — English (UK)",         "gb"),
    ("ru  — Russian",              "ru"),
    ("jp  — Japanese",             "jp"),
    ("cn  — Chinese",              "cn"),
    ("ar  — Arabic",               "ar"),
];

pub const TIMEZONES: &[&str] = &[
    "America/Sao_Paulo",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "America/Toronto",
    "America/Vancouver",
    "America/Manaus",
    "America/Fortaleza",
    "America/Recife",
    "America/Belem",
    "America/Porto_Velho",
    "America/Cuiaba",
    "America/Campo_Grande",
    "America/Rio_Branco",
    "America/Bogota",
    "America/Lima",
    "America/Buenos_Aires",
    "America/Santiago",
    "America/Caracas",
    "America/Mexico_City",
    "America/Halifax",
    "UTC",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Europe/Madrid",
    "Europe/Rome",
    "Europe/Amsterdam",
    "Europe/Lisbon",
    "Europe/Moscow",
    "Asia/Tokyo",
    "Asia/Shanghai",
    "Asia/Seoul",
    "Asia/Kolkata",
    "Asia/Dubai",
    "Asia/Singapore",
    "Asia/Bangkok",
    "Asia/Jakarta",
    "Australia/Sydney",
    "Australia/Melbourne",
    "Australia/Perth",
    "Africa/Cairo",
    "Africa/Johannesburg",
    "Africa/Lagos",
    "Pacific/Auckland",
    "Pacific/Honolulu",
];

// ─── Step ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Step {
    Welcome,
    Language,
    InstallMode,
    Keyboard,
    Timezone,
    Credentials,
    StorageMode,
    Disk,
    Summary,
    Installing,
    Done,
}

impl Step {
    #[allow(dead_code)]
    pub fn index(&self) -> usize {
        match self {
            Step::Welcome     => 0,
            Step::Language    => 1,
            Step::InstallMode => 2,
            Step::Keyboard    => 3,
            Step::Timezone    => 4,
            Step::Credentials => 5,
            Step::StorageMode => 6,
            Step::Disk        => 7,
            Step::Summary     => 8,
            Step::Installing  => 9,
            Step::Done        => 10,
        }
    }

    pub fn title(&self) -> &'static str {
        match self {
            Step::Welcome     => "Welcome",
            Step::Language    => "Language",
            Step::InstallMode => "Installation Mode",
            Step::Keyboard    => "Keyboard Layout",
            Step::Timezone    => "Timezone",
            Step::Credentials => "User Credentials",
            Step::StorageMode => "Installation Type",
            Step::Disk        => "Target Disk",
            Step::Summary     => "Summary",
            Step::Installing  => "Installing",
            Step::Done        => "Complete",
        }
    }

    /// Returns (current, total) wizard step numbers for config steps, None otherwise.
    pub fn wizard_step(&self) -> Option<(usize, usize)> {
        match self {
            Step::Language    => Some((1, 8)),
            Step::InstallMode => Some((2, 8)),
            Step::Keyboard    => Some((3, 8)),
            Step::Timezone    => Some((4, 8)),
            Step::Credentials => Some((5, 8)),
            Step::StorageMode => Some((6, 8)),
            Step::Disk        => Some((7, 8)),
            Step::Summary     => Some((8, 8)),
            _                 => None,
        }
    }

    pub fn next(&self) -> Step {
        match self {
            Step::Welcome     => Step::Language,
            Step::Language    => Step::InstallMode,
            Step::InstallMode => Step::Keyboard,
            Step::Keyboard    => Step::Timezone,
            Step::Timezone    => Step::Credentials,
            Step::Credentials => Step::StorageMode,
            Step::StorageMode => Step::Disk,
            Step::Disk        => Step::Summary,
            Step::Summary     => Step::Installing,
            Step::Installing  => Step::Done,
            Step::Done        => Step::Done,
        }
    }

    pub fn prev(&self) -> Step {
        match self {
            Step::Language    => Step::Welcome,
            Step::InstallMode => Step::Language,
            Step::Keyboard    => Step::InstallMode,
            Step::Timezone    => Step::Keyboard,
            Step::Credentials => Step::Timezone,
            Step::StorageMode => Step::Credentials,
            Step::Disk        => Step::StorageMode,
            Step::Summary     => Step::Disk,
            other             => *other,
        }
    }
}

fn valid_hostname(hostname: &str) -> bool {
    if hostname.len() > 63 || hostname.starts_with('-') || hostname.ends_with('-') {
        return false;
    }
    hostname
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-')
}

fn valid_username(username: &str) -> bool {
    let mut chars = username.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !(first.is_ascii_lowercase() || first == '_') {
        return false;
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' || c == '_')
}

// ─── App ──────────────────────────────────────────────────────────────────────

pub struct App {
    pub step:        Step,
    pub should_quit: bool,
    pub tick:        u64,

    // Language
    pub language_idx: usize,

    // Installation Mode
    pub offline_mode: bool,

    // Keyboard
    pub keyboard_idx: usize,

    // Timezone
    pub timezone_search:   String,
    pub timezone_filtered: Vec<&'static str>,
    pub timezone_idx:      usize,

    // Credentials
    pub hostname:         String,
    pub username:         String,
    pub password:         String,
    pub root_password:    String,
    pub credential_focus: usize, // 0-3
    pub credential_error: Option<String>,
    pub show_pass:        bool,

    // Disk
    pub storage_mode:         StorageMode,
    pub disks:                Vec<DiskInfo>,
    pub alongside_candidates: Vec<AlongsideCandidate>,
    pub disk_idx:             usize,
    pub encrypt:              bool,
    pub luks_pass:            String,
    pub luks_pass2:           String,
    pub bitlocker_ack:        bool,
    pub secure_boot_enabled:  bool,
    pub mok_pass:             String,
    pub mok_pass2:            String,
    pub disk_focus:           usize, // 0=list, 1=encrypt, 2=no encryption, 3-4=LUKS, 5=BitLocker, 6-7=MOK
    pub disk_error:           Option<String>,

    // Summary
    pub summary_yes: bool,

    // Install
    pub install_rx:       Option<Receiver<InstallMessage>>,
    pub install_progress: u16,
    pub install_log:      Vec<String>,
    pub install_error:    Option<String>,

    // Done
    pub reboot_requested: bool,
    pub done_focus:       usize, // 0=reboot, 1=exit
}

impl App {
    pub fn new() -> Self {
        let alongside_candidates = discover_alongside_candidates();
        let storage_mode = if alongside_candidates.is_empty() {
            StorageMode::EraseDisk
        } else {
            StorageMode::AlongsideWindows
        };
        Self {
            step:        Step::Welcome,
            should_quit: false,
            tick:        0,

            language_idx: 0,
            offline_mode: true,
            keyboard_idx: 0,

            timezone_search:   String::new(),
            timezone_filtered: TIMEZONES.to_vec(),
            timezone_idx:      0,

            hostname:         String::new(),
            username:         String::new(),
            password:         String::new(),
            root_password:    String::new(),
            credential_focus: 0,
            credential_error: None,
            show_pass:        false,

            storage_mode,
            disks:                detect_disks(),
            alongside_candidates,
            disk_idx:             0,
            encrypt:              false,
            luks_pass:            String::new(),
            luks_pass2:           String::new(),
            bitlocker_ack:        false,
            secure_boot_enabled:  is_secure_boot_enabled(),
            mok_pass:             String::new(),
            mok_pass2:            String::new(),
            disk_focus:           0,
            disk_error:           None,

            summary_yes: true,

            install_rx:       None,
            install_progress: 0,
            install_log:      Vec::new(),
            install_error:    None,

            reboot_requested: false,
            done_focus:       0,
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    pub fn current_language(&self) -> (&'static str, &'static str, &'static str) {
        LANGUAGES[self.language_idx.min(LANGUAGES.len() - 1)]
    }

    pub fn current_keyboard(&self) -> (&'static str, &'static str) {
        KEYBOARDS[self.keyboard_idx.min(KEYBOARDS.len() - 1)]
    }

    pub fn current_timezone(&self) -> &str {
        self.timezone_filtered
            .get(self.timezone_idx)
            .copied()
            .unwrap_or("UTC")
    }

    pub fn current_disk(&self) -> Option<&DiskInfo> {
        self.disks.get(self.disk_idx)
    }

    pub fn tr<'a>(&self, en: &'a str, pt_br: &'a str, es: &'a str) -> &'a str {
        match self.current_language().1 {
            "pt-br" => pt_br,
            "es" => es,
            _ => en,
        }
    }

    pub fn current_alongside_candidate(&self) -> Option<&AlongsideCandidate> {
        self.alongside_candidates.get(self.disk_idx)
    }

    pub fn current_storage_display(&self) -> String {
        match self.storage_mode {
            StorageMode::EraseDisk => self.current_disk().map(DiskInfo::display),
            StorageMode::AlongsideWindows => self.current_alongside_candidate().map(AlongsideCandidate::display),
        }
        .unwrap_or_else(|| "None selected".to_string())
    }

    // ── Timezone filtering ────────────────────────────────────────────────────

    fn filter_timezones(&mut self) {
        let q = self.timezone_search.to_lowercase();
        self.timezone_filtered = if q.is_empty() {
            TIMEZONES.to_vec()
        } else {
            TIMEZONES.iter()
                .filter(|tz| tz.to_lowercase().contains(&q))
                .copied()
                .collect()
        };
        self.timezone_idx = 0;
    }

    // ── Validation ────────────────────────────────────────────────────────────

    fn validate_credentials(&self) -> Option<String> {
        if self.hostname.is_empty()      { return Some("Hostname cannot be empty".into()); }
        if self.hostname.contains(' ')   { return Some("Hostname cannot contain spaces".into()); }
        if !valid_hostname(&self.hostname) {
            return Some("Hostname must use letters, numbers, and hyphens only".into());
        }
        if self.username.is_empty()      { return Some("Username cannot be empty".into()); }
        if self.username.contains(' ')   { return Some("Username cannot contain spaces".into()); }
        if !valid_username(&self.username) {
            return Some("Username must start with a lowercase letter or underscore and use lowercase letters, numbers, hyphens, or underscores".into());
        }
        if self.password.len() < 6       { return Some("Password must be at least 6 characters".into()); }
        if self.root_password.is_empty() { return Some("Root password cannot be empty".into()); }
        None
    }

    fn validate_disk(&self) -> Option<String> {
        match self.storage_mode {
            StorageMode::EraseDisk if self.disks.is_empty() => return Some("No disks detected".into()),
            StorageMode::AlongsideWindows if self.alongside_candidates.is_empty() => {
                return Some("No eligible Windows installation with at least 64 GiB unallocated was found".into());
            }
            StorageMode::AlongsideWindows => {
                let candidate = self.current_alongside_candidate()?;
                if candidate.bitlocker_detected && !self.bitlocker_ack {
                    return Some("Confirm that the BitLocker recovery key is saved and protection is suspended".into());
                }
            }
            _ => {}
        }
        if self.encrypt {
            if self.luks_pass.len() < 8   { return Some("LUKS password must be at least 8 characters".into()); }
            if self.luks_pass != self.luks_pass2 { return Some("LUKS passwords do not match".into()); }
        }
        if self.secure_boot_enabled {
            if self.mok_pass.len() < 8 || self.mok_pass.len() > 16 || !self.mok_pass.is_ascii() {
                return Some("Secure Boot enrollment password must contain 8-16 ASCII characters".into());
            }
            if self.mok_pass != self.mok_pass2 { return Some("Secure Boot enrollment passwords do not match".into()); }
        }
        None
    }

    // ── Install ───────────────────────────────────────────────────────────────

    fn start_install(&mut self) {
        let storage = match self.storage_mode {
            StorageMode::EraseDisk => StoragePlan::EraseDisk {
                disk: self.current_disk().map(|d| d.path.clone()).unwrap_or_default(),
            },
            StorageMode::AlongsideWindows => {
                let candidate = self.current_alongside_candidate().expect("validated alongside candidate");
                StoragePlan::AlongsideWindows {
                    disk: candidate.disk.path.clone(),
                    disk_size_bytes: candidate.disk.size_bytes,
                    esp_partition: candidate.esp_partition.clone(),
                    esp_uuid: candidate.esp_uuid.clone(),
                    root_partition_number: candidate.root_partition_number,
                    free_region: candidate.free_region.clone(),
                    bitlocker_detected: candidate.bitlocker_detected,
                    secure_boot_enabled: candidate.secure_boot_enabled,
                }
            }
        };
        let (_, lang, locale)  = self.current_language();
        let (_, keymap)        = self.current_keyboard();

        let config = InstallConfig {
            storage,
            encrypt:       self.encrypt,
            luks_pass:     self.luks_pass.clone(),
            hostname:      self.hostname.clone(),
            username:      self.username.clone(),
            password:      self.password.clone(),
            root_password: self.root_password.clone(),
            language:      lang.to_string(),
            locale:        locale.to_string(),
            keymap:        keymap.to_string(),
            timezone:      self.current_timezone().to_string(),
            offline:       self.offline_mode,
            mok_password:  self.mok_pass.clone(),
        };

        self.install_rx = Some(spawn_install(config));
        self.step = Step::Installing;
    }

    pub fn check_install_progress(&mut self) {
        let Some(rx) = &self.install_rx else { return };
        while let Ok(msg) = rx.try_recv() {
            match msg {
                InstallMessage::Progress { percent, message } => {
                    self.install_progress = percent;
                    self.install_log.push(message);
                    if self.install_log.len() > 100 {
                        self.install_log.remove(0);
                    }
                }
                InstallMessage::Error(e) => {
                    self.install_error = Some(e);
                }
                InstallMessage::Done => {
                    self.install_progress = 100;
                    self.step = Step::Done;
                }
            }
        }
    }

    // ── Key handling ──────────────────────────────────────────────────────────

    /// Returns true when the app should exit.
    pub fn handle_key(&mut self, key: KeyEvent) -> bool {
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.should_quit = true;
            return true;
        }
        match self.step {
            Step::Welcome     => self.key_welcome(key),
            Step::Language    => self.key_language(key),
            Step::InstallMode => self.key_install_mode(key),
            Step::Keyboard    => self.key_keyboard(key),
            Step::Timezone    => self.key_timezone(key),
            Step::Credentials => self.key_credentials(key),
            Step::StorageMode => self.key_storage_mode(key),
            Step::Disk        => self.key_disk(key),
            Step::Summary     => self.key_summary(key),
            Step::Installing  => {}
            Step::Done        => return self.key_done(key),
        }
        false
    }

    fn key_welcome(&mut self, key: KeyEvent) {
        if key.code == KeyCode::Enter {
            self.step = self.step.next();
        }
    }

    fn key_language(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Up    => { self.language_idx = self.language_idx.saturating_sub(1); }
            KeyCode::Down  => { self.language_idx = (self.language_idx + 1).min(LANGUAGES.len() - 1); }
            KeyCode::Enter => { self.step = self.step.next(); }
            KeyCode::Esc   => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_install_mode(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Up | KeyCode::Down | KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                self.offline_mode = !self.offline_mode;
            }
            KeyCode::Enter => { self.step = self.step.next(); }
            KeyCode::Esc   => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_keyboard(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Up    => { self.keyboard_idx = self.keyboard_idx.saturating_sub(1); }
            KeyCode::Down  => { self.keyboard_idx = (self.keyboard_idx + 1).min(KEYBOARDS.len() - 1); }
            KeyCode::Enter => { self.step = self.step.next(); }
            KeyCode::Esc   => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_timezone(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                self.timezone_search.push(c);
                self.filter_timezones();
            }
            KeyCode::Backspace => {
                self.timezone_search.pop();
                self.filter_timezones();
            }
            KeyCode::Up => {
                self.timezone_idx = self.timezone_idx.saturating_sub(1);
            }
            KeyCode::Down => {
                if !self.timezone_filtered.is_empty() {
                    self.timezone_idx = (self.timezone_idx + 1).min(self.timezone_filtered.len() - 1);
                }
            }
            KeyCode::Enter => { self.step = self.step.next(); }
            KeyCode::Esc   => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_credentials(&mut self, key: KeyEvent) {
        self.credential_error = None;
        match key.code {
            KeyCode::Tab | KeyCode::Down => {
                self.credential_focus = (self.credential_focus + 1) % 4;
            }
            KeyCode::BackTab | KeyCode::Up => {
                self.credential_focus = self.credential_focus.saturating_sub(1);
            }
            KeyCode::Enter => {
                if self.credential_focus < 3 {
                    self.credential_focus += 1;
                } else if let Some(err) = self.validate_credentials() {
                    self.credential_error = Some(err);
                } else {
                    self.step = self.step.next();
                }
            }
            KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                match self.credential_focus {
                    0 => self.hostname.push(c),
                    1 => self.username.push(c),
                    2 => self.password.push(c),
                    3 => self.root_password.push(c),
                    _ => {}
                }
            }
            KeyCode::Backspace => {
                match self.credential_focus {
                    0 => { self.hostname.pop(); }
                    1 => { self.username.pop(); }
                    2 => { self.password.pop(); }
                    3 => { self.root_password.pop(); }
                    _ => {}
                }
            }
            KeyCode::F(1) => { self.show_pass = !self.show_pass; }
            KeyCode::Esc  => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_storage_mode(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Up | KeyCode::Down | KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                self.storage_mode = match self.storage_mode {
                    StorageMode::EraseDisk => StorageMode::AlongsideWindows,
                    StorageMode::AlongsideWindows => StorageMode::EraseDisk,
                };
                self.disk_idx = 0;
                self.disk_focus = 0;
            }
            KeyCode::Enter => {
                if self.storage_mode == StorageMode::AlongsideWindows && self.alongside_candidates.is_empty() {
                    self.disk_error = Some("No eligible Windows installation was found".into());
                } else {
                    self.disk_idx = 0;
                    self.step = self.step.next();
                }
            }
            KeyCode::Esc => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_disk(&mut self, key: KeyEvent) {
        self.disk_error = None;
        match self.disk_focus {
            // 0: disk list navigation
            0 => match key.code {
                KeyCode::Up    => { self.disk_idx = self.disk_idx.saturating_sub(1); }
                KeyCode::Down  => {
                    let item_count = if self.storage_mode == StorageMode::EraseDisk {
                        self.disks.len()
                    } else {
                        self.alongside_candidates.len()
                    };
                    if item_count > 0 {
                        self.disk_idx = (self.disk_idx + 1).min(item_count - 1);
                    }
                }
                KeyCode::Tab | KeyCode::Enter => { self.disk_focus = 1; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 1: encrypt option
            1 => match key.code {
                KeyCode::Char(' ') => {
                    self.encrypt = true;
                }
                KeyCode::Enter => {
                    self.encrypt = true;
                    self.disk_focus = 3;
                }
                KeyCode::Tab => { self.disk_focus = if self.encrypt { 3 } else { 2 }; }
                KeyCode::Down => { self.disk_focus = 2; }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 0; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 2: no-encryption option
            2 => match key.code {
                KeyCode::Char(' ') => {
                    self.encrypt = false;
                }
                KeyCode::Enter => {
                    self.encrypt = false;
                    if self.storage_mode == StorageMode::AlongsideWindows
                        && self.current_alongside_candidate().is_some_and(|candidate| candidate.bitlocker_detected)
                    {
                        self.disk_focus = 5;
                    } else if self.secure_boot_enabled {
                        self.disk_focus = 6;
                    } else if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Tab | KeyCode::Down => {
                    if self.encrypt {
                        self.disk_focus = 3;
                    } else if self.storage_mode == StorageMode::AlongsideWindows
                        && self.current_alongside_candidate().is_some_and(|candidate| candidate.bitlocker_detected)
                    {
                        self.disk_focus = 5;
                    } else if self.secure_boot_enabled {
                        self.disk_focus = 6;
                    } else if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 1; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 3: LUKS password
            3 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    self.luks_pass.push(c);
                }
                KeyCode::Backspace => { self.luks_pass.pop(); }
                KeyCode::Tab | KeyCode::Down | KeyCode::Enter => { self.disk_focus = 4; }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 1; }
                KeyCode::F(1) => { self.show_pass = !self.show_pass; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 4: LUKS password confirm
            4 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    self.luks_pass2.push(c);
                }
                KeyCode::Backspace => { self.luks_pass2.pop(); }
                KeyCode::Tab | KeyCode::Down | KeyCode::Enter => {
                    if self.storage_mode == StorageMode::AlongsideWindows
                        && self.current_alongside_candidate().is_some_and(|candidate| candidate.bitlocker_detected)
                    {
                        self.disk_focus = 5;
                    } else if self.secure_boot_enabled {
                        self.disk_focus = 6;
                    } else if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 3; }
                KeyCode::F(1) => { self.show_pass = !self.show_pass; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 5: mandatory BitLocker acknowledgement
            5 => match key.code {
                KeyCode::Char(' ') => { self.bitlocker_ack = !self.bitlocker_ack; }
                KeyCode::Enter => {
                    if self.bitlocker_ack && self.secure_boot_enabled {
                        self.disk_focus = 6;
                    } else if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Up | KeyCode::BackTab => {
                    self.disk_focus = if self.encrypt { 4 } else { 2 };
                }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 6: MOK enrollment password
            6 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => self.mok_pass.push(c),
                KeyCode::Backspace => { self.mok_pass.pop(); }
                KeyCode::Tab | KeyCode::Down | KeyCode::Enter => { self.disk_focus = 7; }
                KeyCode::Up | KeyCode::BackTab => {
                    self.disk_focus = if self.storage_mode == StorageMode::AlongsideWindows
                        && self.current_alongside_candidate().is_some_and(|candidate| candidate.bitlocker_detected)
                    { 5 } else if self.encrypt { 4 } else { 2 };
                }
                KeyCode::F(1) => { self.show_pass = !self.show_pass; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 7: MOK enrollment password confirmation
            7 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => self.mok_pass2.push(c),
                KeyCode::Backspace => { self.mok_pass2.pop(); }
                KeyCode::Enter | KeyCode::Tab | KeyCode::Down => {
                    if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 6; }
                KeyCode::F(1) => { self.show_pass = !self.show_pass; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            _ => {}
        }
    }

    fn key_summary(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                self.summary_yes = !self.summary_yes;
            }
            KeyCode::Enter => {
                if self.summary_yes {
                    self.start_install();
                } else {
                    self.step = self.step.prev();
                }
            }
            KeyCode::Esc => { self.step = self.step.prev(); }
            _ => {}
        }
    }

    fn key_done(&mut self, key: KeyEvent) -> bool {
        match key.code {
            KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                self.done_focus = if self.done_focus == 0 { 1 } else { 0 };
            }
            KeyCode::Enter => {
                self.reboot_requested = self.done_focus == 0;
                return true;
            }
            KeyCode::Esc => return true,
            _ => {}
        }
        false
    }
}

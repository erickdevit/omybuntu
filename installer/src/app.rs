use std::sync::mpsc::Receiver;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use crate::install::{InstallConfig, InstallMessage, spawn_install};

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
    Keyboard,
    Timezone,
    Credentials,
    Disk,
    Summary,
    Installing,
    Done,
}

impl Step {
    pub fn index(&self) -> usize {
        match self {
            Step::Welcome     => 0,
            Step::Language    => 1,
            Step::Keyboard    => 2,
            Step::Timezone    => 3,
            Step::Credentials => 4,
            Step::Disk        => 5,
            Step::Summary     => 6,
            Step::Installing  => 7,
            Step::Done        => 8,
        }
    }

    pub fn title(&self) -> &'static str {
        match self {
            Step::Welcome     => "Welcome",
            Step::Language    => "Language",
            Step::Keyboard    => "Keyboard Layout",
            Step::Timezone    => "Timezone",
            Step::Credentials => "User Credentials",
            Step::Disk        => "Target Disk",
            Step::Summary     => "Summary",
            Step::Installing  => "Installing",
            Step::Done        => "Complete",
        }
    }

    /// Returns (current, total) wizard step numbers for config steps, None otherwise.
    pub fn wizard_step(&self) -> Option<(usize, usize)> {
        match self {
            Step::Language    => Some((1, 6)),
            Step::Keyboard    => Some((2, 6)),
            Step::Timezone    => Some((3, 6)),
            Step::Credentials => Some((4, 6)),
            Step::Disk        => Some((5, 6)),
            Step::Summary     => Some((6, 6)),
            _                 => None,
        }
    }

    pub fn next(&self) -> Step {
        match self {
            Step::Welcome     => Step::Language,
            Step::Language    => Step::Keyboard,
            Step::Keyboard    => Step::Timezone,
            Step::Timezone    => Step::Credentials,
            Step::Credentials => Step::Disk,
            Step::Disk        => Step::Summary,
            Step::Summary     => Step::Installing,
            Step::Installing  => Step::Done,
            Step::Done        => Step::Done,
        }
    }

    pub fn prev(&self) -> Step {
        match self {
            Step::Language    => Step::Welcome,
            Step::Keyboard    => Step::Language,
            Step::Timezone    => Step::Keyboard,
            Step::Credentials => Step::Timezone,
            Step::Disk        => Step::Credentials,
            Step::Summary     => Step::Disk,
            other             => *other,
        }
    }
}

// ─── DiskInfo ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct DiskInfo {
    pub path:  String,
    pub size:  String,
    pub model: String,
}

impl DiskInfo {
    pub fn display(&self) -> String {
        format!("{}  {}  {}", self.path, self.size, self.model)
    }
}

fn detect_disks() -> Vec<DiskInfo> {
    let output = std::process::Command::new("lsblk")
        .args(["-d", "-n", "-p", "-o", "NAME,SIZE,MODEL,TYPE", "--pairs"])
        .output();

    match output {
        Ok(out) => String::from_utf8_lossy(&out.stdout)
            .lines()
            .filter(|l| !l.contains("TYPE=\"loop\"") && !l.contains("TYPE=\"rom\""))
            .filter_map(parse_lsblk_pairs)
            .collect(),
        Err(_) => vec![],
    }
}

fn parse_lsblk_pairs(line: &str) -> Option<DiskInfo> {
    let get = |key: &str| -> Option<String> {
        let search = format!("{}=\"", key);
        let start  = line.find(&search)? + search.len();
        let end    = line[start..].find('"')? + start;
        Some(line[start..end].to_string())
    };
    Some(DiskInfo {
        path:  get("NAME")?,
        size:  get("SIZE").unwrap_or_default(),
        model: get("MODEL").unwrap_or_else(|| "Unknown".to_string()),
    })
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
    pub disks:      Vec<DiskInfo>,
    pub disk_idx:   usize,
    pub encrypt:    bool,
    pub luks_pass:  String,
    pub luks_pass2: String,
    pub disk_focus: usize, // 0=list, 1=encrypt toggle, 2=luks_pass, 3=luks_pass2
    pub disk_error: Option<String>,

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
        Self {
            step:        Step::Welcome,
            should_quit: false,
            tick:        0,

            language_idx: 0,
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

            disks:      detect_disks(),
            disk_idx:   0,
            encrypt:    false,
            luks_pass:  String::new(),
            luks_pass2: String::new(),
            disk_focus: 0,
            disk_error: None,

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
        if self.disks.is_empty() { return Some("No disks detected".into()); }
        if self.encrypt {
            if self.luks_pass.len() < 8   { return Some("LUKS password must be at least 8 characters".into()); }
            if self.luks_pass != self.luks_pass2 { return Some("LUKS passwords do not match".into()); }
        }
        None
    }

    // ── Install ───────────────────────────────────────────────────────────────

    fn start_install(&mut self) {
        let disk = self.current_disk().map(|d| d.path.clone()).unwrap_or_default();
        let (_, lang, locale)  = self.current_language();
        let (_, keymap)        = self.current_keyboard();

        let config = InstallConfig {
            disk,
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
            Step::Keyboard    => self.key_keyboard(key),
            Step::Timezone    => self.key_timezone(key),
            Step::Credentials => self.key_credentials(key),
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

    fn key_disk(&mut self, key: KeyEvent) {
        self.disk_error = None;
        match self.disk_focus {
            // 0: disk list navigation
            0 => match key.code {
                KeyCode::Up    => { self.disk_idx = self.disk_idx.saturating_sub(1); }
                KeyCode::Down  => {
                    if !self.disks.is_empty() {
                        self.disk_idx = (self.disk_idx + 1).min(self.disks.len() - 1);
                    }
                }
                KeyCode::Tab | KeyCode::Enter => { self.disk_focus = 1; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 1: encrypt toggle
            1 => match key.code {
                KeyCode::Char(' ') | KeyCode::Enter => {
                    self.encrypt = !self.encrypt;
                    self.disk_focus = if self.encrypt { 2 } else { 1 };
                }
                KeyCode::Tab | KeyCode::Down => {
                    if self.encrypt { self.disk_focus = 2; } else {
                        // No LUKS fields: confirm step
                        if let Some(err) = self.validate_disk() {
                            self.disk_error = Some(err);
                        } else {
                            self.step = self.step.next();
                        }
                    }
                }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 0; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 2: LUKS password
            2 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    self.luks_pass.push(c);
                }
                KeyCode::Backspace => { self.luks_pass.pop(); }
                KeyCode::Tab | KeyCode::Down | KeyCode::Enter => { self.disk_focus = 3; }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 1; }
                KeyCode::Esc => { self.step = self.step.prev(); }
                _ => {}
            },
            // 3: LUKS password confirm
            3 => match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    self.luks_pass2.push(c);
                }
                KeyCode::Backspace => { self.luks_pass2.pop(); }
                KeyCode::Tab | KeyCode::Down | KeyCode::Enter => {
                    if let Some(err) = self.validate_disk() {
                        self.disk_error = Some(err);
                    } else {
                        self.step = self.step.next();
                    }
                }
                KeyCode::Up | KeyCode::BackTab => { self.disk_focus = 2; }
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

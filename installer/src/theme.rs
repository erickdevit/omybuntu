use ratatui::style::{Color, Modifier, Style};

// ─── Palette ──────────────────────────────────────────────────────────────────

pub const BG: Color           = Color::Rgb(13, 15, 20);
pub const SURFACE: Color      = Color::Rgb(24, 26, 34);
pub const BORDER: Color       = Color::Rgb(55, 65, 81);
pub const ACCENT: Color       = Color::Rgb(124, 58, 237);
pub const ACCENT_LIGHT: Color = Color::Rgb(167, 139, 250);
pub const TEXT: Color         = Color::Rgb(226, 232, 240);
pub const MUTED: Color        = Color::Rgb(100, 116, 139);
pub const SUCCESS: Color      = Color::Rgb(16, 185, 129);
pub const ERROR: Color        = Color::Rgb(239, 68, 68);
pub const WARNING: Color      = Color::Rgb(245, 158, 11);

// ─── Style helpers ────────────────────────────────────────────────────────────

pub fn base() -> Style {
    Style::default().fg(TEXT)
}

pub fn accent() -> Style {
    Style::default().fg(ACCENT).add_modifier(Modifier::BOLD)
}

pub fn muted() -> Style {
    Style::default().fg(MUTED)
}

#[allow(dead_code)]
pub fn success() -> Style {
    Style::default().fg(SUCCESS).add_modifier(Modifier::BOLD)
}

pub fn error_style() -> Style {
    Style::default().fg(ERROR).add_modifier(Modifier::BOLD)
}

pub fn warning_style() -> Style {
    Style::default().fg(WARNING).add_modifier(Modifier::BOLD)
}

pub fn selected() -> Style {
    Style::default()
        .fg(Color::White)
        .bg(ACCENT)
        .add_modifier(Modifier::BOLD)
}

pub fn focused_border() -> Style {
    Style::default().fg(ACCENT)
}

pub fn normal_border() -> Style {
    Style::default().fg(BORDER)
}

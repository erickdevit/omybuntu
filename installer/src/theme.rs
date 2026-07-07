use std::{env, fs, path::PathBuf, sync::OnceLock};

use ratatui::style::{Color, Modifier, Style};

// ─── Palette ──────────────────────────────────────────────────────────────────

#[derive(Clone, Copy)]
struct Palette {
    bg:           Color,
    surface:      Color,
    border:       Color,
    accent:       Color,
    accent_light: Color,
    text:         Color,
    muted:        Color,
    success:      Color,
    error:        Color,
    warning:      Color,
    selected_fg:  Color,
}

static PALETTE: OnceLock<Palette> = OnceLock::new();

const FALLBACK: Palette = Palette {
    bg:           Color::Rgb(13, 15, 20),
    surface:      Color::Rgb(24, 26, 34),
    border:       Color::Rgb(55, 65, 81),
    accent:       Color::Rgb(245, 158, 11),
    accent_light: Color::Rgb(251, 146, 60),
    text:         Color::Rgb(226, 232, 240),
    muted:        Color::Rgb(100, 116, 139),
    success:      Color::Rgb(16, 185, 129),
    error:        Color::Rgb(239, 68, 68),
    warning:      Color::Rgb(245, 158, 11),
    selected_fg:  Color::Rgb(20, 10, 5),
};

fn palette() -> &'static Palette {
    PALETTE.get_or_init(load_palette)
}

fn load_palette() -> Palette {
    for path in theme_paths() {
        if let Ok(content) = fs::read_to_string(path) {
            return Palette {
                bg:           color(&content, "background").unwrap_or(FALLBACK.bg),
                surface:      color(&content, "color0").unwrap_or(FALLBACK.surface),
                border:       color(&content, "active_border_color")
                    .or_else(|| color(&content, "color8"))
                    .unwrap_or(FALLBACK.border),
                accent:       color(&content, "accent").unwrap_or(FALLBACK.accent),
                accent_light: color(&content, "cursor")
                    .or_else(|| color(&content, "color12"))
                    .unwrap_or(FALLBACK.accent_light),
                text:         color(&content, "foreground").unwrap_or(FALLBACK.text),
                muted:        color(&content, "color8").unwrap_or(FALLBACK.muted),
                success:      color(&content, "color2").unwrap_or(FALLBACK.success),
                error:        color(&content, "color1").unwrap_or(FALLBACK.error),
                warning:      color(&content, "color3").unwrap_or(FALLBACK.warning),
                selected_fg:  color(&content, "selection_foreground").unwrap_or(FALLBACK.selected_fg),
            };
        }
    }

    FALLBACK
}

fn theme_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if let Ok(home) = env::var("HOME") {
        paths.push(PathBuf::from(format!("{home}/.config/omybuntu/current/theme/colors.toml")));
    }

    if let Ok(omybuntu_path) = env::var("OMYBUNTU_PATH") {
        paths.push(PathBuf::from(format!("{omybuntu_path}/themes/omybuntu/colors.toml")));
    }

    paths.push(PathBuf::from("/opt/omybuntu/themes/omybuntu/colors.toml"));
    paths
}

fn color(content: &str, key: &str) -> Option<Color> {
    let prefix = format!("{key} =");
    content.lines().find_map(|line| {
        let line = line.trim();
        if !line.starts_with(&prefix) {
            return None;
        }

        let value = line.split_once('=')?.1.trim().trim_matches('"');
        rgb(value)
    })
}

fn rgb(hex: &str) -> Option<Color> {
    let hex = hex.strip_prefix('#').unwrap_or(hex);
    if hex.len() != 6 {
        return None;
    }

    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
    Some(Color::Rgb(r, g, b))
}

pub fn bg() -> Color {
    palette().bg
}

pub fn surface() -> Color {
    palette().surface
}

pub fn accent_color() -> Color {
    palette().accent
}

pub fn accent_light_color() -> Color {
    palette().accent_light
}

pub fn text_color() -> Color {
    palette().text
}

pub fn muted_color() -> Color {
    palette().muted
}

pub fn success_color() -> Color {
    palette().success
}

pub fn error_color() -> Color {
    palette().error
}

// ─── Style helpers ────────────────────────────────────────────────────────────

pub fn base() -> Style {
    Style::default().fg(palette().text)
}

pub fn accent() -> Style {
    Style::default().fg(palette().accent).add_modifier(Modifier::BOLD)
}

pub fn muted() -> Style {
    Style::default().fg(palette().muted)
}

#[allow(dead_code)]
pub fn success() -> Style {
    Style::default().fg(palette().success).add_modifier(Modifier::BOLD)
}

pub fn error_style() -> Style {
    Style::default().fg(palette().error).add_modifier(Modifier::BOLD)
}

pub fn warning_style() -> Style {
    Style::default().fg(palette().warning).add_modifier(Modifier::BOLD)
}

pub fn selected() -> Style {
    Style::default()
        .fg(palette().selected_fg)
        .bg(palette().accent)
        .add_modifier(Modifier::BOLD)
}

pub fn focused_border() -> Style {
    Style::default().fg(palette().accent)
}

pub fn normal_border() -> Style {
    Style::default().fg(palette().border)
}

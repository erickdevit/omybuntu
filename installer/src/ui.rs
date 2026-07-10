use ratatui::{
    Frame,
    layout::{Alignment, Constraint, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Gauge, List, ListItem, ListState, Paragraph, Wrap},
};

use crate::app::{App, Step, KEYBOARDS, LANGUAGES};
use crate::theme;

// ─── Welcome logo ─────────────────────────────────────────────────────────────

const LOGO: &[&str] = &[
    r" ▄██████▄    ▄▄▄▄███▄▄▄▄   ▄██   ▄   ▀█████████▄  ███    █▄  ███▄▄▄▄       ███     ███    █▄ ",
    r"███    ███ ▄██▀▀▀███▀▀▀██▄ ███   ██▄   ███    ███ ███    ███ ███▀▀▀██▄ ▀█████████▄ ███    ███",
    r"███    ███ ███   ███   ███ ███▄▄▄███   ███    ███ ███    ███ ███   ███    ▀███▀▀██ ███    ███",
    r"███    ███ ███   ███   ███ ▀▀▀▀▀▀███  ▄███▄▄▄██▀  ███    ███ ███   ███     ███   ▀ ███    ███",
    r"███    ███ ███   ███   ███ ▄██   ███ ▀▀███▀▀▀██▄  ███    ███ ███   ███     ███     ███    ███",
    r"███    ███ ███   ███   ███ ███   ███   ███    ██▄ ███    ███ ███   ███     ███     ███    ███",
    r"███    ███ ███   ███   ███ ███   ███   ███    ███ ███    ███ ███   ███     ███     ███    ███",
    r" ▀██████▀   ▀█   ███   █▀   ▀█████▀  ▄█████████▀  ████████▀   ▀█   █▀     ▄████▀   ████████▀",
];

// ─── Main draw ────────────────────────────────────────────────────────────────

pub fn draw(frame: &mut Frame, app: &mut App) {
    // Fill background
    frame.render_widget(
        Block::default().style(Style::default().bg(theme::bg())),
        frame.area(),
    );

    let root = Layout::vertical([
        Constraint::Length(3), // header
        Constraint::Min(0),    // body
        Constraint::Length(4), // footer
    ])
    .split(frame.area());

    render_header(frame, app, root[0]);
    render_body(frame, app, root[1]);
    render_footer(frame, app, root[2]);
}

// ─── Header ───────────────────────────────────────────────────────────────────

fn render_header(frame: &mut Frame, app: &App, area: Rect) {
    let step_label = match app.step.wizard_step() {
        Some((cur, total)) => format!(" Step {cur}/{total} — {} ", app.step.title()),
        None               => format!(" {} ", app.step.title()),
    };
    let brand = " ◎ OMYBUNTU INSTALLER ";
    let pad = (area.width as usize)
        .saturating_sub(brand.len() + step_label.len() + 2);

    let line = Line::from(vec![
        Span::styled(brand, Style::default().fg(theme::accent_color()).add_modifier(Modifier::BOLD)),
        Span::raw(" ".repeat(pad)),
        Span::styled(&step_label, theme::muted()),
    ]);

    frame.render_widget(
        Paragraph::new(line).block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(theme::focused_border()),
        ),
        area,
    );
}

// ─── Footer ───────────────────────────────────────────────────────────────────

fn render_footer(frame: &mut Frame, app: &App, area: Rect) {
    let hints = match app.step {
        Step::Welcome     => "[Enter] Begin  [Ctrl+C] Quit",
        Step::Language
        | Step::InstallMode
        | Step::Keyboard  => "[↑↓] Navigate  [Enter] Select  [Esc] Back",
        Step::Timezone    => "Type to search  [↑↓] List  [Enter] Confirm  [Esc] Back",
        Step::Credentials => "[Tab/↑↓] Switch field  [Enter] Confirm  [F1] Toggle password  [Esc] Back",
        Step::Disk        => "[↑↓] Navigate  [Space] Select  [Tab] Next field  [F1] Toggle password  [Enter] Confirm",
        Step::Summary     => "[←→] Choose  [Enter] Confirm  [Esc] Back",
        Step::Installing  => "Installing — please wait…",
        Step::Done        => "[←→] Choose  [Enter] Confirm",
    };

    if app.step == Step::Installing {
        let progress = app.install_progress;
        frame.render_widget(
            Gauge::default()
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(theme::normal_border()),
                )
                .gauge_style(Style::default().fg(theme::accent_color()).bg(theme::surface()))
                .percent(progress)
                .label(format!("{progress}%")),
            area,
        );
    } else if app.step == Step::Done {
        let progress = 100;
        let cols = Layout::horizontal([Constraint::Percentage(70), Constraint::Percentage(30)])
            .split(area);

        frame.render_widget(
            Gauge::default()
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(theme::normal_border()),
                )
                .gauge_style(Style::default().fg(theme::accent_color()).bg(theme::surface()))
                .percent(progress)
                .label(format!("{progress}%")),
            cols[0],
        );

        frame.render_widget(
            Paragraph::new(hints)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(theme::normal_border()),
                )
                .style(theme::muted())
                .alignment(Alignment::Center),
            cols[1],
        );
    } else {
        frame.render_widget(
            Paragraph::new(hints)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(theme::normal_border()),
                )
                .style(theme::muted())
                .alignment(Alignment::Center),
            area,
        );
    }
}

// ─── Body dispatcher ──────────────────────────────────────────────────────────

fn render_body(frame: &mut Frame, app: &mut App, area: Rect) {
    match app.step {
        Step::Welcome     => render_welcome(frame, area),
        Step::Language    => render_language(frame, app, area),
        Step::InstallMode => render_install_mode(frame, app, area),
        Step::Keyboard    => render_keyboard(frame, app, area),
        Step::Timezone    => render_timezone(frame, app, area),
        Step::Credentials => render_credentials(frame, app, area),
        Step::Disk        => render_disk(frame, app, area),
        Step::Summary     => render_summary(frame, app, area),
        Step::Installing  => render_installing(frame, app, area),
        Step::Done        => render_done(frame, app, area),
    }
}

// ─── Welcome ──────────────────────────────────────────────────────────────────

fn render_welcome(frame: &mut Frame, area: Rect) {
    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::accent_color()))
        .style(Style::default().bg(theme::bg()));
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let mut lines: Vec<Line> = vec![Line::from("")];

    for row in LOGO {
        lines.push(Line::from(Span::styled(
            *row,
            Style::default().fg(theme::accent_color()).add_modifier(Modifier::BOLD),
        )));
    }

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  Linux. Refined.",
        Style::default().fg(theme::text_color()).add_modifier(Modifier::ITALIC),
    )));
    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  Press ENTER to begin installation",
        Style::default().fg(theme::accent_light_color()).add_modifier(Modifier::BOLD),
    )));

    let h = lines.len() as u16;
    let y = inner.height.saturating_sub(h) / 2;
    frame.render_widget(
        Paragraph::new(lines),
        Rect { x: inner.x, y: inner.y + y, width: inner.width, height: h.min(inner.height) },
    );
}

// ─── Language ─────────────────────────────────────────────────────────────────

fn render_language(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Select Language ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let items: Vec<ListItem> = LANGUAGES.iter().enumerate().map(|(i, (name, _, locale))| {
        let sym   = if i == app.language_idx { "●" } else { "○" };
        let style = if i == app.language_idx { theme::selected() } else { theme::base() };
        ListItem::new(Line::from(Span::styled(
            format!("  {sym}  {name:<28}  {locale}"),
            style,
        )))
    }).collect();

    let mut state = ListState::default();
    state.select(Some(app.language_idx));
    let list_area = v_center(inner, LANGUAGES.len() as u16);
    frame.render_stateful_widget(List::new(items), list_area, &mut state);
}

// ─── Install Mode ─────────────────────────────────────────────────────────────

fn render_install_mode(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Select Installation Mode ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let offline_sym = if app.offline_mode { "●" } else { "○" };
    let online_sym  = if !app.offline_mode { "●" } else { "○" };

    let offline_style = if app.offline_mode { theme::selected() } else { theme::base() };
    let online_style  = if !app.offline_mode { theme::selected() } else { theme::base() };

    let items = vec![
        ListItem::new(vec![
            Line::from(Span::styled(format!("  {}  Offline Installation (Recommended / Faster)", offline_sym), offline_style)),
            Line::from(Span::styled("      Installs directly from the Live ISO without downloading anything.", theme::muted())),
            Line::from(Span::styled("      Takes 1-2 minutes to complete.", theme::muted())),
            Line::from(""),
        ]),
        ListItem::new(vec![
            Line::from(Span::styled(format!("  {}  Online Installation (Slower)", online_sym), online_style)),
            Line::from(Span::styled("      Downloads the latest packages and updates from Ubuntu servers.", theme::muted())),
            Line::from(Span::styled("      Requires internet and takes 10-30 minutes.", theme::muted())),
        ]),
    ];

    let list_area = v_center(inner, 7);
    frame.render_widget(List::new(items), list_area);
}

// ─── Keyboard ─────────────────────────────────────────────────────────────────

fn render_keyboard(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Keyboard Layout ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let items: Vec<ListItem> = KEYBOARDS.iter().enumerate().map(|(i, (label, _))| {
        let sym   = if i == app.keyboard_idx { "●" } else { "○" };
        let style = if i == app.keyboard_idx { theme::selected() } else { theme::base() };
        ListItem::new(Line::from(Span::styled(
            format!("  {sym}  {label}"),
            style,
        )))
    }).collect();

    let mut state = ListState::default();
    state.select(Some(app.keyboard_idx));
    frame.render_stateful_widget(List::new(items), inner, &mut state);
}

// ─── Timezone ─────────────────────────────────────────────────────────────────

fn render_timezone(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Timezone ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let rows = Layout::vertical([Constraint::Length(3), Constraint::Min(0)]).split(inner);

    // Search box
    frame.render_widget(
        Paragraph::new(format!(" Search: {}▏", app.timezone_search))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(theme::focused_border()),
            )
            .style(theme::base()),
        rows[0],
    );

    // Filtered list
    let items: Vec<ListItem> = app.timezone_filtered.iter().enumerate().map(|(i, tz)| {
        let sym   = if i == app.timezone_idx { "●" } else { "○" };
        let style = if i == app.timezone_idx { theme::selected() } else { theme::base() };
        ListItem::new(Line::from(Span::styled(format!("  {sym}  {tz}"), style)))
    }).collect();

    let mut state = ListState::default();
    state.select(Some(app.timezone_idx));
    frame.render_stateful_widget(List::new(items), rows[1], &mut state);
}

// ─── Credentials ──────────────────────────────────────────────────────────────

fn render_credentials(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" User & System Credentials ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    // top-margin + (label + input + gap) × 4 + error
    let constraints: Vec<Constraint> = std::iter::once(Constraint::Length(1))
        .chain(
            (0..4).flat_map(|_| {
                [Constraint::Length(1), Constraint::Length(3), Constraint::Length(1)]
            }),
        )
        .chain(std::iter::once(Constraint::Min(0)))
        .collect();
    let chunks = Layout::vertical(constraints).split(inner);

    let fields: [(&str, &str, bool); 4] = [
        ("Hostname",      &app.hostname,      false),
        ("Username",      &app.username,      false),
        ("Password",      &app.password,      !app.show_pass),
        ("Root Password", &app.root_password, !app.show_pass),
    ];

    let mut ci = 1usize; // chunk index
    for (idx, (label, value, masked)) in fields.iter().enumerate() {
        let focused = idx == app.credential_focus;
        let border  = if focused { theme::focused_border() } else { theme::normal_border() };
        let lbl_sty = if focused { theme::accent() } else { theme::muted() };

        frame.render_widget(
            Paragraph::new(format!("  {label}")).style(lbl_sty),
            chunks[ci],
        );
        ci += 1;

        let display = if *masked { "●".repeat(value.len()) } else { (*value).to_string() };
        let cursor  = if focused { "▏" } else { "" };
        frame.render_widget(
            Paragraph::new(format!("  {display}{cursor}"))
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(border),
                )
                .style(theme::base()),
            chunks[ci],
        );
        ci += 2; // skip gap
    }

    // Error
    if let Some(err) = &app.credential_error {
        frame.render_widget(
            Paragraph::new(format!("  ✕  {err}")).style(theme::error_style()),
            chunks[ci],
        );
    } else if !app.show_pass {
        frame.render_widget(
            Paragraph::new("  [F1] Show/hide passwords").style(theme::muted()),
            chunks[ci],
        );
    }
}

// ─── Disk ─────────────────────────────────────────────────────────────────────

fn render_disk(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Target Disk ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let luks_h: u16 = if app.encrypt { 7 } else { 0 };
    let rows = Layout::vertical([
        Constraint::Min(0),
        Constraint::Length(6),
        Constraint::Length(luks_h),
        Constraint::Length(2),
    ])
    .split(inner);

    // ── Disk list
    if app.disks.is_empty() {
        frame.render_widget(
            Paragraph::new("  No disks detected. Boot with a target disk connected.")
                .style(theme::error_style()),
            rows[0],
        );
    } else {
        let items: Vec<ListItem> = app.disks.iter().enumerate().map(|(i, d)| {
            let sym = if i == app.disk_idx { "●" } else { "○" };
            let style = if i == app.disk_idx && app.disk_focus == 0 {
                theme::selected()
            } else if i == app.disk_idx {
                Style::default().fg(theme::accent_light_color())
            } else {
                theme::base()
            };
            ListItem::new(Line::from(Span::styled(format!("  {sym}  {}", d.display()), style)))
        }).collect();

        let border = if app.disk_focus == 0 { theme::focused_border() } else { theme::normal_border() };
        let mut state = ListState::default();
        state.select(Some(app.disk_idx));
        frame.render_stateful_widget(
            List::new(items).block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(border),
            ),
            rows[0],
            &mut state,
        );
    }

    // ── Encryption choice
    let encryption_rows = Layout::vertical([
        Constraint::Length(3),
        Constraint::Length(3),
    ])
    .split(rows[1]);

    let enc_border = if app.disk_focus == 1 { theme::focused_border() } else { theme::normal_border() };
    let enc_check = if app.encrypt { "●" } else { "○" };
    let enc_style = if app.disk_focus == 1 {
        Style::default().fg(theme::accent_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::base()
    };
    frame.render_widget(
        Paragraph::new(format!("  {enc_check}  Encrypt disk with LUKS"))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(enc_border),
            )
            .style(enc_style),
        encryption_rows[0],
    );

    let plain_border = if app.disk_focus == 2 { theme::focused_border() } else { theme::normal_border() };
    let plain_check = if app.encrypt { "○" } else { "●" };
    let plain_style = if app.disk_focus == 2 {
        Style::default().fg(theme::accent_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::base()
    };
    frame.render_widget(
        Paragraph::new(format!("  {plain_check}  Do not encrypt disk"))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(plain_border),
            )
            .style(plain_style),
        encryption_rows[1],
    );

    // ── LUKS fields
    if app.encrypt {
        let luks_rows = Layout::vertical([
            Constraint::Length(3),
            Constraint::Length(1),
            Constraint::Length(3),
        ])
        .split(rows[2]);

        let luks_fields: [(&str, &str, usize); 2] = [
            ("Encryption Password",         &app.luks_pass,  3),
            ("Confirm Encryption Password", &app.luks_pass2, 4),
        ];

        for (i, (label, val, focus_id)) in luks_fields.iter().enumerate() {
            let focused = app.disk_focus == *focus_id;
            let border  = if focused { theme::focused_border() } else { theme::normal_border() };
            let display = if app.show_pass { (*val).to_string() } else { "●".repeat(val.len()) };
            let cursor  = if focused { "▏" } else { "" };
            frame.render_widget(
                Paragraph::new(format!("  {display}{cursor}  [{label}]"))
                    .block(
                        Block::default()
                            .borders(Borders::ALL)
                            .border_type(BorderType::Rounded)
                            .border_style(border),
                    )
                    .style(theme::base()),
                luks_rows[i * 2],
            );
        }
    }

    // ── Error
    if let Some(err) = &app.disk_error {
        frame.render_widget(
            Paragraph::new(format!("  ✕  {err}")).style(theme::error_style()),
            rows[3],
        );
    } else if app.encrypt && !app.show_pass {
        frame.render_widget(
            Paragraph::new("  [F1] Show/hide passwords").style(theme::muted()),
            rows[3],
        );
    }
}

// ─── Summary ──────────────────────────────────────────────────────────────────

fn render_summary(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(" Installation Summary ");
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let rows_layout = Layout::vertical([
        Constraint::Min(0),
        Constraint::Length(1),
        Constraint::Length(1),
        Constraint::Length(3),
    ])
    .split(inner);

    let (lang_name, _, locale) = app.current_language();
    let (kb_label, _)          = app.current_keyboard();
    let disk_info = app
        .current_disk()
        .map(|d| d.display())
        .unwrap_or_else(|| "None selected".to_string());

    let table: &[(&str, &dyn Fn() -> String)] = &[
        ("Language",   &|| format!("{} ({})", lang_name, locale)),
        ("Keyboard",   &|| kb_label.to_string()),
        ("Timezone",   &|| app.current_timezone().to_string()),
        ("Hostname",   &|| app.hostname.clone()),
        ("Username",   &|| app.username.clone()),
        ("Disk",       &|| disk_info.clone()),
        ("Encryption", &|| if app.encrypt { "LUKS (enabled)".into() } else { "None".into() }),
    ];

    let lines: Vec<Line> = table
        .iter()
        .map(|(key, val_fn)| {
            Line::from(vec![
                Span::styled(format!("  {key:<14} "), theme::muted()),
                Span::styled(val_fn(), theme::base()),
            ])
        })
        .collect();

    frame.render_widget(Paragraph::new(lines), rows_layout[0]);

    frame.render_widget(
        Paragraph::new("  ⚠  This will ERASE ALL DATA on the selected disk!")
            .style(theme::warning_style())
            .alignment(Alignment::Center),
        rows_layout[1],
    );

    // Buttons
    let btns = Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(rows_layout[3]);

    let yes_sty = if app.summary_yes {
        Style::default().fg(theme::bg()).bg(theme::success_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::muted()
    };
    let no_sty = if !app.summary_yes {
        Style::default().fg(theme::bg()).bg(theme::error_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::muted()
    };

    frame.render_widget(
        Paragraph::new("  ✓  Yes, install Omybuntu")
            .style(yes_sty)
            .alignment(Alignment::Center),
        btns[0],
    );
    frame.render_widget(
        Paragraph::new("  ✕  No, go back")
            .style(no_sty)
            .alignment(Alignment::Center),
        btns[1],
    );
}

// ─── Installing ───────────────────────────────────────────────────────────────

fn render_installing(frame: &mut Frame, app: &App, area: Rect) {
    let border_style = if app.install_error.is_some() {
        Style::default().fg(theme::error_color())
    } else {
        Style::default().fg(theme::accent_color())
    };

    let title = if app.install_error.is_some() {
        " Installation Error "
    } else {
        " Installing Omybuntu "
    };

    let outer = Block::default()
        .title(title)
        .title_style(theme::accent())
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(border_style)
        .style(Style::default().bg(theme::bg()));
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let rows = Layout::vertical([
        Constraint::Length(1), // spinner + current op
        Constraint::Length(1), // gap
        Constraint::Min(0),    // log / error
    ])
    .split(inner);

    // Spinner
    const SPIN: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
    let spin = SPIN[(app.tick as usize / 2) % SPIN.len()];
    let current = app.install_log.last().map(String::as_str).unwrap_or("Starting…");
    frame.render_widget(
        Paragraph::new(format!("  {spin}  {current}")).style(theme::accent()),
        rows[0],
    );

    // Error or log
    if let Some(err) = &app.install_error {
        frame.render_widget(
            Paragraph::new(vec![
                Line::from(Span::styled("  Installation failed:", theme::error_style())),
                Line::from(Span::styled(format!("  {err}"), theme::error_style())),
                Line::from(""),
                Line::from(Span::styled("  Press Ctrl+C to exit.", theme::muted())),
            ])
            .wrap(Wrap { trim: false }),
            rows[2],
        );
    } else {
        let log_items: Vec<ListItem> = app.install_log.iter().rev()
            .map(|l| ListItem::new(Line::from(Span::styled(format!("  {l}"), theme::muted()))))
            .collect();
        frame.render_widget(List::new(log_items), rows[2]);
    }
}

// ─── Done ─────────────────────────────────────────────────────────────────────

fn render_done(frame: &mut Frame, app: &App, area: Rect) {
    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::success_color()))
        .style(Style::default().bg(theme::bg()));
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let rows = Layout::vertical([Constraint::Min(0), Constraint::Length(3)]).split(inner);

    frame.render_widget(
        Paragraph::new(vec![
            Line::from(""),
            Line::from(Span::styled(
                "  ✓  Installation Complete!",
                Style::default().fg(theme::success_color()).add_modifier(Modifier::BOLD),
            )),
            Line::from(""),
            Line::from(Span::styled("  Omybuntu has been successfully installed.", theme::base())),
            Line::from(Span::styled(
                "  Remove the installation media and reboot into your new system.",
                theme::muted(),
            )),
        ]),
        rows[0],
    );

    let btns = Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(rows[1]);

    frame.render_widget(
        Paragraph::new("  ↺  Reboot now")
            .style(if app.done_focus == 0 {
                Style::default().fg(theme::bg()).bg(theme::success_color()).add_modifier(Modifier::BOLD)
            } else {
                theme::muted()
            })
            .alignment(Alignment::Center),
        btns[0],
    );
    frame.render_widget(
        Paragraph::new("  ✕  Exit installer")
            .style(if app.done_focus == 1 {
                Style::default().fg(theme::bg()).bg(theme::muted_color()).add_modifier(Modifier::BOLD)
            } else {
                theme::muted()
            })
            .alignment(Alignment::Center),
        btns[1],
    );
}

// ─── UI helpers ───────────────────────────────────────────────────────────────

fn titled_block(title: &'static str) -> Block<'static> {
    Block::default()
        .title(title)
        .title_style(theme::accent())
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(theme::normal_border())
        .style(Style::default().bg(theme::bg()))
}

fn v_center(area: Rect, content_h: u16) -> Rect {
    let y = area.height.saturating_sub(content_h) / 2;
    Rect { x: area.x, y: area.y + y, width: area.width, height: content_h.min(area.height) }
}

use ratatui::{
    Frame,
    layout::{Alignment, Constraint, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Gauge, List, ListItem, ListState, Paragraph, Wrap},
};

use crate::app::{App, Step, KEYBOARDS, LANGUAGES};
use crate::storage::StorageMode;
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
        Constraint::Length(5), // footer
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
        | Step::Keyboard
        | Step::StorageMode => "[↑↓] Navigate  [Enter] Select  [Esc] Back",
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

        render_centered_hint(frame, hints, cols[1]);
    } else {
        render_centered_hint(frame, hints, area);
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
        Step::StorageMode => render_storage_mode(frame, app, area),
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

// ─── Storage Mode ────────────────────────────────────────────────────────────

fn render_storage_mode(frame: &mut Frame, app: &App, area: Rect) {
    let outer = titled_block(app.tr(
        " Select Installation Type ",
        " Selecione o tipo de instalação ",
        " Seleccione el tipo de instalación ",
    ));
    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let alongside_selected = app.storage_mode == StorageMode::AlongsideWindows;
    let erase_selected = app.storage_mode == StorageMode::EraseDisk;
    let alongside_available = !app.alongside_candidates.is_empty();
    let alongside_style = if alongside_selected && alongside_available {
        theme::selected()
    } else if alongside_available {
        theme::base()
    } else {
        theme::muted()
    };
    let erase_style = if erase_selected { theme::selected() } else { theme::base() };
    let alongside_detail = if alongside_available {
        let template = app.tr(
            "eligible Windows layout(s) found with at least 64 GiB free",
            "layout(s) Windows elegível(is) encontrado(s) com pelo menos 64 GiB livres",
            "diseño(s) de Windows compatible(s) encontrado(s) con al menos 64 GiB libres",
        );
        format!("      {} {template}.", app.alongside_candidates.len())
    } else {
        app.tr(
            "      Requires UEFI/GPT Windows and at least 64 GiB of unallocated space.",
            "      Requer Windows UEFI/GPT e pelo menos 64 GiB de espaço não alocado.",
            "      Requiere Windows UEFI/GPT y al menos 64 GiB de espacio no asignado.",
        ).to_string()
    };

    let items = vec![
        ListItem::new(vec![
            Line::from(Span::styled(
                format!("  {}  {}", if alongside_selected { "●" } else { "○" }, app.tr(
                    "Install alongside Windows (Recommended)",
                    "Instalar ao lado do Windows (Recomendado)",
                    "Instalar junto a Windows (Recomendado)",
                )),
                alongside_style,
            )),
            Line::from(Span::styled(app.tr(
                "      Preserves Windows, reuses its EFI partition, and creates one Omybuntu partition.",
                "      Preserva o Windows, reutiliza sua partição EFI e cria uma partição Omybuntu.",
                "      Conserva Windows, reutiliza su partición EFI y crea una partición Omybuntu.",
            ), theme::muted())),
            Line::from(Span::styled(alongside_detail, theme::muted())),
            Line::from(""),
        ]),
        ListItem::new(vec![
            Line::from(Span::styled(
                format!("  {}  {}", if erase_selected { "●" } else { "○" }, app.tr(
                    "Erase the entire selected disk",
                    "Apagar todo o disco selecionado",
                    "Borrar todo el disco seleccionado",
                )),
                erase_style,
            )),
            Line::from(Span::styled(app.tr(
                "      Deletes every partition and all data on the selected disk.",
                "      Exclui todas as partições e dados do disco selecionado.",
                "      Elimina todas las particiones y datos del disco seleccionado.",
            ), theme::warning_style())),
        ]),
    ];

    frame.render_widget(List::new(items), v_center(inner, 8));
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
    let bitlocker_h: u16 = if app.storage_mode == StorageMode::AlongsideWindows
        && app.current_alongside_candidate().is_some_and(|candidate| candidate.bitlocker_detected)
    {
        4
    } else {
        0
    };
    let mok_h: u16 = if app.secure_boot_enabled { 7 } else { 0 };
    let rows = Layout::vertical([
        Constraint::Min(0),
        Constraint::Length(6),
        Constraint::Length(luks_h),
        Constraint::Length(bitlocker_h),
        Constraint::Length(mok_h),
        Constraint::Length(2),
    ])
    .split(inner);

    // ── Disk list
    let item_count = if app.storage_mode == StorageMode::EraseDisk {
        app.disks.len()
    } else {
        app.alongside_candidates.len()
    };
    if item_count == 0 {
        frame.render_widget(
            Paragraph::new(if app.storage_mode == StorageMode::EraseDisk {
                "  No disks detected. Boot with a target disk connected."
            } else {
                app.tr(
                    "  No eligible Windows UEFI/GPT installation with 64 GiB unallocated was found.",
                    "  Nenhuma instalação Windows UEFI/GPT com 64 GiB não alocados foi encontrada.",
                    "  No se encontró una instalación Windows UEFI/GPT con 64 GiB sin asignar.",
                )
            })
                .style(theme::error_style()),
            rows[0],
        );
    } else {
        let labels: Vec<String> = if app.storage_mode == StorageMode::EraseDisk {
            app.disks.iter().map(|disk| disk.display()).collect()
        } else {
            app.alongside_candidates.iter().map(|candidate| {
                format!(
                    "{}  ESP {}  free region {}",
                    candidate.display(),
                    candidate.esp_partition,
                    candidate.free_region.display_size()
                )
            }).collect()
        };
        let items: Vec<ListItem> = labels.iter().enumerate().map(|(i, label)| {
            let sym = if i == app.disk_idx { "●" } else { "○" };
            let style = if i == app.disk_idx && app.disk_focus == 0 {
                theme::selected()
            } else if i == app.disk_idx {
                Style::default().fg(theme::accent_light_color())
            } else {
                theme::base()
            };
            ListItem::new(Line::from(Span::styled(format!("  {sym}  {label}"), style)))
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

    if bitlocker_h > 0 {
        let focused = app.disk_focus == 5;
        let check = if app.bitlocker_ack { "☑" } else { "☐" };
        frame.render_widget(
            Paragraph::new(vec![
                Line::from(Span::styled(
                    format!("  {check}  {}", app.tr(
                        "I saved the BitLocker recovery key and suspended protection in Windows",
                        "Salvei a chave de recuperação do BitLocker e suspendi a proteção no Windows",
                        "Guardé la clave de recuperación de BitLocker y suspendí la protección en Windows",
                    )),
                    if focused { theme::selected() } else { theme::warning_style() },
                )),
                Line::from(Span::styled(app.tr(
                    "      Omybuntu will not mount or modify the Windows data partition.",
                    "      A Omybuntu não montará nem modificará a partição de dados do Windows.",
                    "      Omybuntu no montará ni modificará la partición de datos de Windows.",
                ), theme::muted())),
            ])
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(if focused { theme::focused_border() } else { theme::normal_border() }),
            ),
            rows[3],
        );
    }

    if mok_h > 0 {
        let mok_rows = Layout::vertical([
            Constraint::Length(1),
            Constraint::Length(3),
            Constraint::Length(3),
        ]).split(rows[4]);
        frame.render_widget(
            Paragraph::new(app.tr(
                "  Secure Boot: choose a one-time password for MOK enrollment after reboot",
                "  Secure Boot: escolha uma senha temporária para cadastrar a MOK após reiniciar",
                "  Secure Boot: elija una contraseña temporal para registrar la MOK al reiniciar",
            ))
                .style(theme::muted()),
            mok_rows[0],
        );
        let fields: [(&str, &str, usize); 2] = [
            ("MOK Enrollment Password", &app.mok_pass, 6),
            ("Confirm MOK Password", &app.mok_pass2, 7),
        ];
        for (index, (label, value, focus_id)) in fields.iter().enumerate() {
            let focused = app.disk_focus == *focus_id;
            let display = if app.show_pass { (*value).to_string() } else { "●".repeat(value.len()) };
            let cursor = if focused { "▏" } else { "" };
            frame.render_widget(
                Paragraph::new(format!("  {display}{cursor}  [{label}]"))
                    .block(
                        Block::default()
                            .borders(Borders::ALL)
                            .border_type(BorderType::Rounded)
                            .border_style(if focused { theme::focused_border() } else { theme::normal_border() }),
                    )
                    .style(theme::base()),
                mok_rows[index + 1],
            );
        }
    }

    // ── Error
    if let Some(err) = &app.disk_error {
        frame.render_widget(
            Paragraph::new(format!("  ✕  {err}")).style(theme::error_style()),
            rows[5],
        );
    } else if app.encrypt && !app.show_pass {
        frame.render_widget(
            Paragraph::new("  [F1] Show/hide passwords").style(theme::muted()),
            rows[5],
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
    let disk_info = app.current_storage_display();
    let install_type = app.storage_mode.label();

    let table: &[(&str, &dyn Fn() -> String)] = &[
        ("Language",   &|| format!("{} ({})", lang_name, locale)),
        ("Keyboard",   &|| kb_label.to_string()),
        ("Timezone",   &|| app.current_timezone().to_string()),
        ("Hostname",   &|| app.hostname.clone()),
        ("Username",   &|| app.username.clone()),
        ("Install type", &|| install_type.to_string()),
        ("Disk",       &|| disk_info.clone()),
        ("Encryption", &|| if app.encrypt { "LUKS (enabled)".into() } else { "None".into() }),
        ("Secure Boot", &|| if app.secure_boot_enabled { "Enabled; MOK enrollment queued".into() } else { "Disabled".into() }),
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

    let warning = if app.storage_mode == StorageMode::EraseDisk {
        app.tr(
            "  ⚠  This will ERASE ALL DATA on the selected disk!",
            "  ⚠  Isto APAGARÁ TODOS OS DADOS do disco selecionado!",
            "  ⚠  ¡Esto BORRARÁ TODOS LOS DATOS del disco seleccionado!",
        )
    } else {
        app.tr(
            "  Windows partitions will be preserved; only the selected free region will be formatted.",
            "  As partições do Windows serão preservadas; apenas a região livre será formatada.",
            "  Las particiones de Windows se conservarán; solo se formateará la región libre.",
        )
    };
    frame.render_widget(
        Paragraph::new(warning)
            .style(if app.storage_mode == StorageMode::EraseDisk { theme::warning_style() } else { theme::accent() })
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

    let mut done_lines = vec![
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
        ];
    if app.secure_boot_enabled {
        done_lines.extend([
            Line::from(""),
            Line::from(Span::styled(app.tr(
                "  Secure Boot: on the blue MokManager screen select Enroll MOK, confirm, and reboot.",
                "  Secure Boot: na tela azul do MokManager, selecione Enroll MOK, confirme e reinicie.",
                "  Secure Boot: en MokManager, seleccione Enroll MOK, confirme y reinicie.",
            ), theme::warning_style())),
            Line::from(Span::styled(app.tr(
                "  Use the one-time MOK password entered during installation.",
                "  Use a senha temporária de MOK informada durante a instalação.",
                "  Use la contraseña temporal de MOK indicada durante la instalación.",
            ), theme::muted())),
        ]);
    }
    frame.render_widget(
        Paragraph::new(done_lines),
        rows[0],
    );

    let btns = Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(rows[1]);

    let reboot_style = if app.done_focus == 0 {
        Style::default().fg(theme::bg()).bg(theme::success_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::muted()
    };
    let exit_style = if app.done_focus == 1 {
        Style::default().fg(theme::bg()).bg(theme::muted_color()).add_modifier(Modifier::BOLD)
    } else {
        theme::muted()
    };

    render_centered_button(frame, "↺  Reboot now", btns[0], reboot_style);
    render_centered_button(frame, "✕  Exit installer", btns[1], exit_style);
}

// ─── UI helpers ───────────────────────────────────────────────────────────────

fn render_centered_hint(frame: &mut Frame, text: &str, area: Rect) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(theme::normal_border());
    let inner = block.inner(area);
    frame.render_widget(block, area);
    frame.render_widget(
        Paragraph::new(text)
            .style(theme::muted())
            .alignment(Alignment::Center),
        v_center(inner, 1),
    );
}

fn render_centered_button(frame: &mut Frame, text: &str, area: Rect, style: Style) {
    frame.render_widget(Block::default().style(style), area);
    frame.render_widget(
        Paragraph::new(text)
            .style(style)
            .alignment(Alignment::Center),
        v_center(area, 1),
    );
}

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

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::{Terminal, backend::TestBackend};

    fn rendered_text(app: &mut App) -> String {
        let backend = TestBackend::new(120, 36);
        let mut terminal = Terminal::new(backend).expect("test terminal");
        terminal.draw(|frame| draw(frame, app)).expect("render installer");
        let buffer = terminal.backend().buffer();
        (0..buffer.area.height)
            .map(|y| {
                (0..buffer.area.width)
                    .map(|x| buffer[(x, y)].symbol().to_string())
                    .collect::<String>()
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    #[test]
    fn storage_mode_screen_renders_safe_choices_and_requirements() {
        let mut app = App::new();
        app.step = Step::StorageMode;
        app.storage_mode = StorageMode::AlongsideWindows;
        let output = rendered_text(&mut app);
        if std::env::var_os("OMYBUNTU_RENDER_SNAPSHOT").is_some() {
            std::fs::write("/tmp/omybuntu-storage-screen.txt", &output).expect("write TUI snapshot");
        }
        assert!(output.contains("Install alongside Windows"));
        assert!(output.contains("64 GiB"));
        assert!(output.contains("Erase the entire selected disk"));
    }

    #[test]
    fn alongside_summary_does_not_show_the_erase_disk_warning() {
        let mut app = App::new();
        app.step = Step::Summary;
        app.storage_mode = StorageMode::AlongsideWindows;
        let output = rendered_text(&mut app);
        assert!(output.contains("Windows partitions will be preserved"));
        assert!(!output.contains("ERASE ALL DATA"));
    }

    #[test]
    fn alongside_disk_screen_fits_luks_bitlocker_and_mok_controls() {
        let mut app = App::new();
        app.step = Step::Disk;
        app.storage_mode = StorageMode::AlongsideWindows;
        app.encrypt = true;
        app.secure_boot_enabled = true;
        app.alongside_candidates = vec![crate::storage::AlongsideCandidate {
            disk: crate::storage::DiskInfo {
                path: "/dev/nvme0n1".into(),
                size: "512.0 GiB".into(),
                size_bytes: 512 * 1024 * 1024 * 1024,
                model: "Test SSD".into(),
            },
            esp_partition: "/dev/nvme0n1p1".into(),
            esp_uuid: "ABCD-1234".into(),
            root_partition_number: 4,
            free_region: crate::storage::FreeRegion {
                start_sector: 1_000_000,
                end_sector: 300_000_000,
                size_bytes: 140 * 1024 * 1024 * 1024,
            },
            bitlocker_detected: true,
            secure_boot_enabled: true,
        }];
        let output = rendered_text(&mut app);
        assert!(output.contains("BitLocker recovery key"));
        assert!(output.contains("MOK Enrollment Password"));
        assert!(output.contains("Confirm MOK Password"));
    }
}

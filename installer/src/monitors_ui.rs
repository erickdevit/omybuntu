use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, Paragraph},
    Frame,
};
use crate::monitors_app::{App, MenuState, Monitor};

pub fn draw(f: &mut Frame, app: &mut App) {
    let size = f.area();

    // Split screen: Header (3), Preview (9), Bottom Half (remainder)
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(9),
            Constraint::Min(10),
        ])
        .split(size);

    // 1. Header block
    let header_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Cyan));
    let title_para = Paragraph::new(Line::from(vec![
        Span::styled(
            format!(" {} ", app.translations.title),
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            " - omybuntu monitor manager",
            Style::default().fg(Color::DarkGray),
        ),
    ]))
    .block(header_block);
    f.render_widget(title_para, chunks[0]);

    // 2. Preview block
    let preview_block = Block::default()
        .title(" [ Connected Screens Preview ] ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::DarkGray));
    
    let preview_area = chunks[1];
    f.render_widget(preview_block, preview_area);

    // Inner area of the preview block
    let inner_preview = Rect {
        x: preview_area.x + 1,
        y: preview_area.y + 1,
        width: preview_area.width.saturating_sub(2),
        height: preview_area.height.saturating_sub(2),
    };

    // Split preview space into columns dynamically matching the number of monitors
    if !app.monitors.is_empty() {
        let cols_count = app.monitors.len();
        let mut constraints = Vec::new();
        for _ in 0..cols_count {
            constraints.push(Constraint::Length(36));
        }
        
        let preview_cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(constraints)
            .split(inner_preview);

        for (i, monitor) in app.monitors.iter().enumerate() {
            if i < preview_cols.len() {
                draw_monitor_box(f, preview_cols[i], monitor, i, app);
            }
        }
    }

    // 3. Bottom half divided horizontally: Left (Selected Details), Right (Actions menu)
    let bottom_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(chunks[2]);

    // Left: Selected Monitor Details
    let selected_mon = app.monitors.get(app.selected_idx).or_else(|| app.monitors.first());
    let details_block = Block::default()
        .title(" [ Selected Monitor Details ] ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::DarkGray));
        
    let details_text = if let Some(m) = selected_mon {
        let type_str = if m.name.contains("eDP") {
            "Laptop"
        } else if m.name.contains("HDMI") {
            "HDMI"
        } else if m.name.contains("DP") {
            "DisplayPort"
        } else {
            "Other"
        };
        
        let status = if m.disabled {
            app.translations.disabled.to_string()
        } else if !m.mirror_of.is_empty() && m.mirror_of != "none" {
            format!("Mirroring {}", m.mirror_of)
        } else {
            format!("Active ({}x{} @ {}Hz)", m.width, m.height, m.refresh_rate.round())
        };

        vec![
            Line::from(vec![
                Span::styled("Name: ", Style::default().fg(Color::DarkGray)),
                Span::styled(&m.name, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            ]),
            Line::from(vec![
                Span::styled("Make/Model: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{} {}", m.make, m.model), Style::default().fg(Color::White)),
            ]),
            Line::from(vec![
                Span::styled("Type: ", Style::default().fg(Color::DarkGray)),
                Span::styled(type_str, Style::default().fg(Color::White)),
            ]),
            Line::from(vec![
                Span::styled("Scale: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{}x", m.scale), Style::default().fg(Color::White)),
            ]),
            Line::from(vec![
                Span::styled("Position: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{}x{}", m.x, m.y), Style::default().fg(Color::White)),
            ]),
            Line::from(vec![
                Span::styled("Rotation: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{}°", m.transform * 90), Style::default().fg(Color::White)),
            ]),
            Line::from(vec![
                Span::styled("Status: ", Style::default().fg(Color::DarkGray)),
                Span::styled(status, Style::default().fg(if m.disabled { Color::Red } else { Color::Green })),
            ]),
        ]
    } else {
        vec![Line::from("No monitors selected")]
    };

    let details_para = Paragraph::new(details_text).block(details_block);
    f.render_widget(details_para, bottom_chunks[0]);

    // Right: Actions / Options List
    let actions_block = Block::default()
        .title(format!(" [ {} ] ", app.translations.select_action))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::DarkGray));

    let mut actions_items = Vec::new();
    for (i, m) in app.monitors.iter().enumerate() {
        let lbl = format!("Configure Monitor {} ({})", i + 1, m.name);
        actions_items.push(lbl);
    }
    actions_items.push(app.translations.preset_mirror.to_string());
    actions_items.push(app.translations.preset_extend.to_string());
    actions_items.push(app.translations.preset_screen1.to_string());
    actions_items.push(app.translations.preset_screen2.to_string());
    actions_items.push("Exit TUI".to_string());

    let list_items: Vec<ListItem> = actions_items
        .iter()
        .enumerate()
        .map(|(i, item)| {
            if i == app.selected_idx {
                ListItem::new(format!("> {}", item)).style(
                    Style::default()
                        .fg(Color::Cyan)
                        .add_modifier(Modifier::BOLD),
                )
            } else {
                ListItem::new(format!("  {}", item))
            }
        })
        .collect();

    let list = List::new(list_items).block(actions_block);
    f.render_widget(list, bottom_chunks[1]);

    // 4. Overlays / Popups
    match app.current_menu {
        MenuState::MonitorSelected => {
            let monitor = &app.monitors[app.selected_idx];
            let mut opts = Vec::new();
            if monitor.disabled {
                opts.push(app.translations.enable.to_string());
            } else {
                opts.push(app.translations.resolution.to_string());
                opts.push(app.translations.scale.to_string());
                opts.push(app.translations.position.to_string());
                opts.push(app.translations.rotation.to_string());
                opts.push(app.translations.disable.to_string());
            }
            opts.push(app.translations.back.to_string());
            render_popup(f, size, &format!("Configure {}", monitor.name), &opts, app.selected_sub_idx);
        }
        MenuState::ChangeResolution => {
            render_popup(f, size, app.translations.select_res, &app.resolutions, app.selected_sub_idx);
        }
        MenuState::ChangeScale => {
            render_popup(f, size, app.translations.select_scale, &app.scales, app.selected_sub_idx);
        }
        MenuState::ChangePosition => {
            render_popup(f, size, app.translations.select_pos, &app.positions, app.selected_sub_idx);
        }
        MenuState::ChangeRotation => {
            render_popup(f, size, app.translations.select_rot, &app.rotations, app.selected_sub_idx);
        }
        _ => {}
    }
}

fn draw_monitor_box(f: &mut Frame, area: Rect, monitor: &Monitor, index: usize, app: &App) {
    let mut border_color = Color::White;
    if monitor.focused {
        border_color = Color::Cyan;
    } else if monitor.disabled {
        border_color = Color::DarkGray;
    }

    let is_selected_main = app.current_menu == MenuState::Main && app.selected_idx == index;
    let block_title = if is_selected_main {
        format!(" >> Monitor [{}] << ", index + 1)
    } else {
        format!(" Monitor [{}] ", index + 1)
    };

    let block = Block::default()
        .title(block_title)
        .borders(Borders::ALL)
        .border_style(Style::default().fg(border_color));

    let type_str = if monitor.name.contains("eDP") {
        "Laptop"
    } else if monitor.name.contains("HDMI") {
        "HDMI"
    } else if monitor.name.contains("DP") {
        "DisplayPort"
    } else {
        "Other"
    };

    let mut lines = vec![
        Line::from(vec![
            Span::styled("Port: ", Style::default().fg(Color::DarkGray)),
            Span::styled(&monitor.name, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            Span::styled(format!(" ({})", type_str), Style::default().fg(Color::DarkGray)),
        ]),
    ];

    if monitor.disabled {
        lines.push(Line::from(vec![
            Span::styled("Status: ", Style::default().fg(Color::DarkGray)),
            Span::styled(app.translations.disabled, Style::default().fg(Color::Red)),
        ]));
        lines.push(Line::from(""));
        lines.push(Line::from(""));
    } else {
        if !monitor.mirror_of.is_empty() && monitor.mirror_of != "none" {
            lines.push(Line::from(vec![
                Span::styled("Status: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("Mirroring {}", monitor.mirror_of), Style::default().fg(Color::Magenta)),
            ]));
        } else {
            lines.push(Line::from(vec![
                Span::styled("Res: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{}x{}@{}Hz", monitor.width, monitor.height, monitor.refresh_rate.round()), Style::default().fg(Color::White)),
            ]));
        }
        lines.push(Line::from(vec![
            Span::styled("Scale: ", Style::default().fg(Color::DarkGray)),
            Span::styled(format!("{}x", monitor.scale), Style::default().fg(Color::White)),
        ]));
        
        let mut status_line = Vec::new();
        status_line.push(Span::styled(format!("* {} *", app.translations.active), Style::default().fg(Color::Green)));
        if monitor.focused {
            status_line.push(Span::styled("  ", Style::default()));
            status_line.push(Span::styled(format!("* {} *", app.translations.focused), Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)));
        }
        lines.push(Line::from(status_line));
    }

    let para = Paragraph::new(lines).block(block);
    f.render_widget(para, area);
}

fn render_popup(f: &mut Frame, area: Rect, title: &str, items: &[String], selected_idx: usize) {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - 50) / 2),
            Constraint::Percentage(50),
            Constraint::Percentage((100 - 50) / 2),
        ])
        .split(area);

    let popup_area = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - 60) / 2),
            Constraint::Percentage(60),
            Constraint::Percentage((100 - 60) / 2),
        ])
        .split(popup_layout[1])[1];

    f.render_widget(Clear, popup_area);

    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Yellow));

    let list_items: Vec<ListItem> = items
        .iter()
        .enumerate()
        .map(|(i, item)| {
            if i == selected_idx {
                ListItem::new(format!("> {}", item)).style(
                    Style::default()
                        .fg(Color::Yellow)
                        .add_modifier(Modifier::BOLD),
                )
            } else {
                ListItem::new(format!("  {}", item))
            }
        })
        .collect();

    let list = List::new(list_items).block(block);
    f.render_widget(list, popup_area);
}

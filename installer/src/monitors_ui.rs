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

    // Split screen: Header (3), Preview (Min(12)), Help Bar (3)
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(12),
            Constraint::Length(3),
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
            " - omybuntu",
            Style::default().fg(Color::DarkGray),
        ),
    ]))
    .block(header_block);
    f.render_widget(title_para, chunks[0]);

    // 2. Preview block
    let preview_block = Block::default()
        .title(" [ Connected Screens Layout ] ")
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

    // Split preview space into columns dynamically, centering the boxes
    if !app.monitors.is_empty() {
        let cols_count = app.monitors.len();
        
        // Calculate box dimensions for each monitor based on aspect ratio
        let mut box_dims = Vec::new();
        for m in &app.monitors {
            let mut box_w = 38; // Default landscape
            let box_h = 10;
            if m.width > 0 && m.height > 0 {
                let ratio = m.width as f32 / m.height as f32;
                if ratio < 1.0 {
                    box_w = 26; // Portrait square-ish box
                }
            }
            box_dims.push((box_w, box_h));
        }

        let gap = 4;
        let total_w = box_dims.iter().map(|d| d.0).sum::<u16>() + (cols_count - 1) as u16 * gap;
        
        let padding = if inner_preview.width > total_w {
            (inner_preview.width - total_w) / 2
        } else {
            0
        };

        let mut constraints = Vec::new();
        if padding > 0 {
            constraints.push(Constraint::Length(padding));
        }
        for (i, dim) in box_dims.iter().enumerate() {
            constraints.push(Constraint::Length(dim.0));
            if i < cols_count - 1 {
                constraints.push(Constraint::Length(gap));
            }
        }
        constraints.push(Constraint::Min(0));

        let preview_cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(constraints)
            .split(inner_preview);

        let mut monitor_rects = Vec::new();
        let mut col_idx = if padding > 0 { 1 } else { 0 };
        for _ in 0..cols_count {
            if col_idx < preview_cols.len() {
                monitor_rects.push(preview_cols[col_idx]);
            }
            col_idx += 2;
        }

        for (i, monitor) in app.monitors.iter().enumerate() {
            if i < monitor_rects.len() {
                let col_rect = monitor_rects[i];
                let (box_w, box_h) = box_dims[i];
                
                // Center the box area inside the column rect
                let mut box_area = col_rect;
                if col_rect.height > box_h {
                    box_area.y += (col_rect.height - box_h) / 2;
                    box_area.height = box_h;
                }
                if col_rect.width > box_w {
                    box_area.x += (col_rect.width - box_w) / 2;
                    box_area.width = box_w;
                }
                
                draw_monitor_box(f, box_area, monitor, i, app);
            }
        }
    }

    // 3. Help Bar
    let help_block = Block::default()
        .title(" [ Keyboard Shortcuts & Navigation ] ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::DarkGray));
        
    let help_para = Paragraph::new(Line::from(Span::styled(
        app.translations.help_text,
        Style::default().fg(Color::Yellow),
    )))
    .block(help_block)
    .alignment(ratatui::layout::Alignment::Center);
    
    f.render_widget(help_para, chunks[2]);

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
            Span::styled(format!("{}: ", app.translations.label_port), Style::default().fg(Color::DarkGray)),
            Span::styled(&monitor.name, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            Span::styled(format!(" ({})", type_str), Style::default().fg(Color::DarkGray)),
        ]),
        Line::from(vec![
            Span::styled(format!("{}: ", app.translations.label_model), Style::default().fg(Color::DarkGray)),
            Span::styled(format!("{} {}", monitor.make, monitor.model), Style::default().fg(Color::White)),
        ]),
    ];

    if monitor.disabled {
        lines.push(Line::from(vec![
            Span::styled(format!("{}: ", app.translations.label_status), Style::default().fg(Color::DarkGray)),
            Span::styled(app.translations.disabled, Style::default().fg(Color::Red)),
        ]));
        // Muted lines to preserve height structure cleanly
        lines.push(Line::from(""));
        lines.push(Line::from(""));
        lines.push(Line::from(""));
        lines.push(Line::from(""));
    } else {
        if !monitor.mirror_of.is_empty() && monitor.mirror_of != "none" {
            lines.push(Line::from(vec![
                Span::styled(format!("{}: ", app.translations.label_status), Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{} {}", app.translations.label_mirroring, monitor.mirror_of), Style::default().fg(Color::Magenta)),
            ]));
        } else {
            lines.push(Line::from(vec![
                Span::styled(format!("{}: ", app.translations.label_res), Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{}x{}@{}Hz", monitor.width, monitor.height, monitor.refresh_rate.round()), Style::default().fg(Color::White)),
            ]));
        }
        lines.push(Line::from(vec![
            Span::styled(format!("{}: ", app.translations.label_scale), Style::default().fg(Color::DarkGray)),
            Span::styled(format!("{}x", monitor.scale), Style::default().fg(Color::White)),
        ]));
        lines.push(Line::from(vec![
            Span::styled(format!("{}: ", app.translations.label_pos), Style::default().fg(Color::DarkGray)),
            Span::styled(format!("{}x{}", monitor.x, monitor.y), Style::default().fg(Color::White)),
        ]));
        lines.push(Line::from(vec![
            Span::styled(format!("{}: ", app.translations.label_rot), Style::default().fg(Color::DarkGray)),
            Span::styled(format!("{}°", monitor.transform * 90), Style::default().fg(Color::White)),
        ]));
    }

    let mut status_line = Vec::new();
    if !monitor.disabled {
        status_line.push(Span::styled(format!("* {} *", app.translations.active), Style::default().fg(Color::Green)));
    }
    if monitor.focused {
        if !status_line.is_empty() {
            status_line.push(Span::styled("  ", Style::default()));
        }
        status_line.push(Span::styled(format!("* {} *", app.translations.focused), Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)));
    }
    lines.push(Line::from(status_line));

    let para = Paragraph::new(lines).block(block);
    f.render_widget(para, area);
}

fn render_popup(f: &mut Frame, area: Rect, title: &str, items: &[String], selected_idx: usize) {
    // Dynamic popup dimensions based on contents
    let popup_h = (items.len() + 2) as u16;
    
    let mut max_len = 25;
    for item in items {
        if item.len() > max_len {
            max_len = item.len();
        }
    }
    let popup_w = (max_len + 6) as u16;

    let mut popup_area = area;
    if area.height > popup_h {
        popup_area.y += (area.height - popup_h) / 2;
        popup_area.height = popup_h;
    }
    if area.width > popup_w {
        popup_area.x += (area.width - popup_w) / 2;
        popup_area.width = popup_w;
    }

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

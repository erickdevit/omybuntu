use std::io;
use std::time::Duration;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

mod app;
mod install;
mod theme;
mod ui;

fn main() {
    enable_raw_mode().expect("Failed to enable raw mode");
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)
        .expect("Failed to enter alternate screen");

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).expect("Failed to create terminal");

    let mut app = app::App::new();

    loop {
        terminal.draw(|f| ui::draw(f, &mut app)).expect("Failed to draw");
        app.check_install_progress();
        app.tick = app.tick.wrapping_add(1);

        if event::poll(Duration::from_millis(100)).unwrap_or(false) {
            if let Ok(Event::Key(key)) = event::read() {
                if app.handle_key(key) {
                    break;
                }
            }
        }

        if app.should_quit {
            break;
        }
    }

    // Restore terminal
    disable_raw_mode().expect("Failed to disable raw mode");
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture,
    )
    .expect("Failed to leave alternate screen");
    terminal.show_cursor().expect("Failed to show cursor");

    if app.reboot_requested {
        std::process::Command::new("reboot").status().ok();
    }
}

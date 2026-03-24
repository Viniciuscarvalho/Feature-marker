use crate::model::{AppMode, AppState};
use crate::ui::screens;
use crate::ui::Theme;
use ratatui::prelude::*;

/// Main layout renderer
pub fn render_layout(frame: &mut Frame, state: &AppState, theme: &Theme) {
    match &state.mode {
        AppMode::Welcome => {
            screens::render_welcome(frame, state, theme);
        }
        AppMode::FeatureSelection => {
            screens::render_feature_select(frame, state, theme);
        }
        AppMode::PromptInput => {
            screens::render_prompt_input(frame, state, theme);
        }
        AppMode::ModeSelection => {
            screens::render_mode_select(frame, state, theme);
        }
        AppMode::Executing | AppMode::Paused => {
            screens::render_dashboard(frame, state, theme);
        }
        AppMode::Completed => {
            screens::render_completed(frame, state, theme);
        }
        AppMode::Error(msg) => {
            screens::render_error(frame, msg, theme);
        }
        AppMode::KanbanView => {
            screens::render_kanban(frame, state, theme);
        }
        AppMode::Quitting => {
            // Nothing to render, app is quitting
        }
    }
}

/// Create the main three-part layout (header, body, footer)
pub fn main_layout(area: Rect) -> (Rect, Rect, Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(5),  // Header
            Constraint::Min(10),    // Body
            Constraint::Length(1),  // Footer
        ])
        .split(area);

    (chunks[0], chunks[1], chunks[2])
}

/// Create sidebar + main content layout
pub fn sidebar_layout(area: Rect) -> (Rect, Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(25),  // Sidebar
            Constraint::Percentage(75),  // Main
        ])
        .split(area);

    (chunks[0], chunks[1])
}

/// Center a block in the given area
pub fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}

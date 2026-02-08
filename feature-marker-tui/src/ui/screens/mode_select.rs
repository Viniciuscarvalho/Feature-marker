use crate::model::{AppState, ExecutionMode};
use crate::ui::layout::{centered_rect, main_layout};
use crate::ui::widgets;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph};

/// Render the mode selection screen
pub fn render_mode_select(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let (header, body, footer) = main_layout(area);

    // Header with banner
    widgets::render_banner(frame, header, theme);

    // Main content
    let center = centered_rect(70, 80, body);

    let feature_name = state
        .feature
        .as_ref()
        .map(|f| f.feature_name.as_str())
        .unwrap_or("Unknown");

    let block = Block::default()
        .title(format!(" Select Execution Mode - {} ", feature_name))
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(theme.style_border());

    let inner = block.inner(center);
    frame.render_widget(block, center);

    // Split into description and list
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Description
            Constraint::Min(10),   // List
        ])
        .margin(1)
        .split(inner);

    // Description
    let description = Paragraph::new(vec![
        Line::from("Choose how to execute the feature workflow:"),
        Line::from(""),
    ]);
    frame.render_widget(description, chunks[0]);

    // Mode list
    let modes = ExecutionMode::all();
    let items: Vec<ListItem> = modes
        .iter()
        .enumerate()
        .map(|(i, mode)| {
            let is_selected = i == state.ui.selected_index;
            let style = if is_selected {
                theme.style_selected()
            } else {
                Style::default()
            };

            let prefix = if is_selected { "▶ " } else { "  " };

            let number = format!("{}. ", i + 1);

            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(prefix, style),
                    Span::styled(number, theme.style_muted()),
                    Span::styled(mode.name(), style),
                ]),
                Line::from(vec![
                    Span::raw("     "),
                    Span::styled(mode.description(), theme.style_muted()),
                ]),
                Line::from(""),
            ])
        })
        .collect();

    let list = List::new(items).highlight_style(theme.style_selected());

    let mut list_state = ListState::default();
    list_state.select(Some(state.ui.selected_index));

    frame.render_stateful_widget(list, chunks[1], &mut list_state);

    // Footer
    widgets::render_status_bar(frame, footer, state, theme);
}

use crate::model::AppState;
use crate::ui::layout::{centered_rect, main_layout};
use crate::ui::widgets;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph};

/// Render the feature selection screen
pub fn render_feature_select(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let (header, body, footer) = main_layout(area);

    // Header with banner
    widgets::render_banner(frame, header, theme);

    // Main content
    let center = centered_rect(70, 80, body);

    let block = Block::default()
        .title(" Select Feature ")
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(theme.style_border());

    let inner = block.inner(center);
    frame.render_widget(block, center);

    // Split into input area and list area
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(4), // Input area
            Constraint::Min(5),    // List area
        ])
        .margin(1)
        .split(inner);

    // Input mode handling
    if state.ui.input_mode {
        render_input_mode(frame, chunks[0], state, theme);
    } else {
        render_prompt(frame, chunks[0], theme);
    }

    // Feature list
    render_feature_list(frame, chunks[1], state, theme);

    // Footer
    widgets::render_status_bar(frame, footer, state, theme);
}

fn render_prompt(frame: &mut Frame, area: Rect, theme: &Theme) {
    let lines = vec![
        Line::from(Span::styled(
            "Enter a new feature name or select an existing one:",
            Style::default(),
        )),
        Line::from(""),
        Line::from(vec![
            Span::styled("Press ", theme.style_muted()),
            Span::styled("n", theme.style_primary()),
            Span::styled(" to create new feature, ", theme.style_muted()),
            Span::styled("Enter", theme.style_primary()),
            Span::styled(" to select, ", theme.style_muted()),
            Span::styled("Esc", theme.style_primary()),
            Span::styled(" to go back", theme.style_muted()),
        ]),
    ];

    let paragraph = Paragraph::new(lines);
    frame.render_widget(paragraph, area);
}

fn render_input_mode(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let input_block = Block::default()
        .title(" New Feature Name ")
        .borders(Borders::ALL)
        .border_style(theme.style_primary());

    let input_area = input_block.inner(area);
    frame.render_widget(input_block, area);

    let input_text = Paragraph::new(state.ui.input_buffer.as_str())
        .style(Style::default().fg(Color::White));
    frame.render_widget(input_text, input_area);

    // Show cursor
    frame.set_cursor_position(Position::new(
        input_area.x + state.ui.input_buffer.len() as u16,
        input_area.y,
    ));
}

fn render_feature_list(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    if state.available_features.is_empty() {
        let empty_msg = Paragraph::new(vec![
            Line::from(""),
            Line::from(Span::styled(
                "No existing features found.",
                theme.style_muted(),
            )),
            Line::from(Span::styled(
                "Press 'n' to create a new feature.",
                theme.style_muted(),
            )),
        ])
        .alignment(Alignment::Center);
        frame.render_widget(empty_msg, area);
        return;
    }

    let items: Vec<ListItem> = state
        .available_features
        .iter()
        .enumerate()
        .map(|(i, feature)| {
            let style = if i == state.ui.selected_index {
                theme.style_selected()
            } else {
                Style::default()
            };

            let prefix = if i == state.ui.selected_index {
                "▶ "
            } else {
                "  "
            };

            ListItem::new(Line::from(vec![
                Span::styled(prefix, style),
                Span::styled(feature.clone(), style),
            ]))
        })
        .collect();

    let list = List::new(items)
        .block(
            Block::default()
                .title(" Existing Features ")
                .borders(Borders::ALL)
                .border_style(theme.style_border()),
        )
        .highlight_style(theme.style_selected());

    let mut list_state = ListState::default();
    list_state.select(Some(state.ui.selected_index));

    frame.render_stateful_widget(list, area, &mut list_state);
}

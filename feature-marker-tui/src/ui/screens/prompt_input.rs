use crate::model::AppState;
use crate::ui::layout::{centered_rect, main_layout};
use crate::ui::widgets;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Paragraph};

/// Render the prompt input screen for new features
pub fn render_prompt_input(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let (header, body, footer) = main_layout(area);

    // Header with banner
    widgets::render_banner(frame, header, theme);

    // Centered content block
    let center = centered_rect(70, 70, body);

    let feature_name = state
        .feature
        .as_ref()
        .map(|f| f.feature_name.as_str())
        .unwrap_or("New Feature");

    let block = Block::default()
        .title(format!(" Feature Prompt — {} ", feature_name))
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(theme.style_primary());

    let inner = block.inner(center);
    frame.render_widget(block, center);

    // Split into instruction and text area
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Instruction
            Constraint::Min(5),    // Text area
        ])
        .margin(1)
        .split(inner);

    // Instruction line
    let instruction = Paragraph::new(vec![
        Line::from(vec![
            Span::styled(
                "Describe what you want to build",
                Style::default(),
            ),
            Span::styled(" (optional — ", theme.style_muted()),
            Span::styled("Enter", theme.style_primary()),
            Span::styled(" to skip)", theme.style_muted()),
        ]),
        Line::from(""),
    ]);
    frame.render_widget(instruction, chunks[0]);

    // Text area with prompt buffer
    let text_block = Block::default()
        .title(" Prompt ")
        .borders(Borders::ALL)
        .border_style(theme.style_border_focused());

    let text_inner = text_block.inner(chunks[1]);
    frame.render_widget(text_block, chunks[1]);

    let display_text = if state.ui.prompt_buffer.is_empty() {
        Paragraph::new(Span::styled(
            "Start typing...",
            theme.style_muted(),
        ))
    } else {
        Paragraph::new(state.ui.prompt_buffer.as_str())
            .style(Style::default().fg(Color::White))
            .wrap(ratatui::widgets::Wrap { trim: false })
    };
    frame.render_widget(display_text, text_inner);

    // Show cursor at end of input
    if !state.ui.prompt_buffer.is_empty() {
        // Count lines and position cursor
        let lines: Vec<&str> = state.ui.prompt_buffer.split('\n').collect();
        let last_line_len = lines.last().map(|l| l.len()).unwrap_or(0) as u16;
        let line_count = lines.len().saturating_sub(1) as u16;
        let cursor_y = text_inner.y + line_count;
        let cursor_x = text_inner.x + last_line_len;

        if cursor_y < text_inner.y + text_inner.height
            && cursor_x < text_inner.x + text_inner.width
        {
            frame.set_cursor_position(Position::new(cursor_x, cursor_y));
        }
    } else {
        frame.set_cursor_position(Position::new(text_inner.x, text_inner.y));
    }

    // Footer
    widgets::render_status_bar(frame, footer, state, theme);
}

use crate::ui::layout::centered_rect;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};

/// Render the error screen
pub fn render_error(frame: &mut Frame, message: &str, theme: &Theme) {
    let area = frame.area();
    let center = centered_rect(60, 40, area);

    let content = vec![
        Line::from(""),
        Line::from(Span::styled("✗ Error Occurred", theme.style_error())),
        Line::from(""),
        Line::from(message.to_string()),
        Line::from(""),
        Line::from(""),
        Line::from(vec![
            Span::styled("Press ", theme.style_muted()),
            Span::styled("r", theme.style_primary()),
            Span::styled(" to retry, ", theme.style_muted()),
            Span::styled("s", theme.style_primary()),
            Span::styled(" to skip, ", theme.style_muted()),
            Span::styled("q", theme.style_primary()),
            Span::styled(" to quit", theme.style_muted()),
        ]),
    ];

    let block = Block::default()
        .title(" Error ")
        .title_style(theme.style_error())
        .borders(Borders::ALL)
        .border_style(theme.style_error());

    let paragraph = Paragraph::new(content)
        .block(block)
        .alignment(Alignment::Center)
        .wrap(Wrap { trim: true });

    frame.render_widget(paragraph, center);
}

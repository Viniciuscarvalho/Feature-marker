use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::Paragraph;

/// Render the feature-marker banner
pub fn render_banner(frame: &mut Frame, area: Rect, theme: &Theme) {
    let banner_lines = vec![
        Line::from(Span::styled(
            "╔═══════════════════════════════════════════════════════════════════════════════╗",
            theme.style_primary(),
        )),
        Line::from(vec![
            Span::styled("║", theme.style_primary()),
            Span::styled("           feature-marker", theme.style_header()),
            Span::styled(" TUI v0.1.0", theme.style_muted()),
            Span::styled("                                              ║", theme.style_primary()),
        ]),
        Line::from(Span::styled(
            "╚═══════════════════════════════════════════════════════════════════════════════╝",
            theme.style_primary(),
        )),
    ];

    let paragraph = Paragraph::new(banner_lines).alignment(Alignment::Center);
    frame.render_widget(paragraph, area);
}

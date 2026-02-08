use crate::model::AppState;
use crate::ui::layout::centered_rect;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Paragraph};

/// Render the welcome screen with banner
pub fn render_welcome(frame: &mut Frame, _state: &AppState, theme: &Theme) {
    let area = frame.area();

    // Background
    frame.render_widget(Block::default().style(Style::default()), area);

    // Centered content
    let center = centered_rect(60, 50, area);

    let banner = vec![
        Line::from(""),
        Line::from(Span::styled(
            "╔═══════════════════════════════════════════════════════╗",
            theme.style_primary(),
        )),
        Line::from(Span::styled(
            "║                                                       ║",
            theme.style_primary(),
        )),
        Line::from(vec![
            Span::styled("║         ", theme.style_primary()),
            Span::styled("feature-marker", theme.style_header()),
            Span::styled(" TUI v0.1.0", theme.style_muted()),
            Span::styled("              ║", theme.style_primary()),
        ]),
        Line::from(Span::styled(
            "║                                                       ║",
            theme.style_primary(),
        )),
        Line::from(vec![
            Span::styled("║   ", theme.style_primary()),
            Span::styled("AI-assisted feature development automation", theme.style_muted()),
            Span::styled("      ║", theme.style_primary()),
        ]),
        Line::from(Span::styled(
            "║                                                       ║",
            theme.style_primary(),
        )),
        Line::from(Span::styled(
            "╚═══════════════════════════════════════════════════════╝",
            theme.style_primary(),
        )),
        Line::from(""),
        Line::from(""),
        Line::from(Span::styled(
            "Press Enter to start or q to quit",
            theme.style_muted(),
        )),
    ];

    let paragraph = Paragraph::new(banner).alignment(Alignment::Center);

    frame.render_widget(paragraph, center);
}

/// Render the completed screen
pub fn render_completed(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let center = centered_rect(60, 50, area);

    let feature_name = state
        .feature
        .as_ref()
        .map(|f| f.feature_name.as_str())
        .unwrap_or("Feature");

    let content = vec![
        Line::from(""),
        Line::from(Span::styled("✓ Workflow Completed!", theme.style_success())),
        Line::from(""),
        Line::from(Span::styled(
            format!("Feature: {}", feature_name),
            Style::default(),
        )),
        Line::from(""),
        Line::from("All phases have been successfully completed."),
        Line::from(""),
        Line::from(Span::styled(
            "Press q to quit or Enter to start a new feature",
            theme.style_muted(),
        )),
    ];

    let block = Block::default()
        .title(" Completed ")
        .borders(Borders::ALL)
        .border_style(theme.style_success());

    let paragraph = Paragraph::new(content)
        .block(block)
        .alignment(Alignment::Center);

    frame.render_widget(paragraph, center);
}

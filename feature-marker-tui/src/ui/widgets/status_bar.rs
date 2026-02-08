use crate::model::{AppMode, AppState};
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::Paragraph;

/// Render the status bar with keyboard shortcuts
pub fn render_status_bar(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let shortcuts = match &state.mode {
        AppMode::Welcome => vec![
            ("Enter", "Start"),
            ("q", "Quit"),
        ],
        AppMode::FeatureSelection => {
            if state.ui.input_mode {
                vec![
                    ("Enter", "Confirm"),
                    ("Esc", "Cancel"),
                ]
            } else {
                vec![
                    ("j/k", "Navigate"),
                    ("n", "New"),
                    ("Enter", "Select"),
                    ("Esc", "Back"),
                    ("q", "Quit"),
                ]
            }
        }
        AppMode::ModeSelection => vec![
            ("j/k", "Navigate"),
            ("1-4", "Quick Select"),
            ("Enter", "Confirm"),
            ("Esc", "Back"),
            ("q", "Quit"),
        ],
        AppMode::Executing => vec![
            ("p", "Pause"),
            ("s", "Toggle Scroll"),
            ("Tab", "Switch Focus"),
            ("q", "Quit"),
        ],
        AppMode::Paused => vec![
            ("r", "Resume"),
            ("s", "Toggle Scroll"),
            ("Tab", "Switch Focus"),
            ("q", "Quit"),
        ],
        AppMode::Completed => vec![
            ("Enter", "New Feature"),
            ("q", "Quit"),
        ],
        AppMode::Error(_) => vec![
            ("r", "Retry"),
            ("s", "Skip"),
            ("q", "Quit"),
        ],
        AppMode::Quitting => vec![],
    };

    let spans: Vec<Span> = shortcuts
        .into_iter()
        .flat_map(|(key, action)| {
            vec![
                Span::styled(format!(" [{}] ", key), theme.style_primary()),
                Span::styled(format!("{} ", action), theme.style_muted()),
                Span::raw(" "),
            ]
        })
        .collect();

    // Add phase info on the right for dashboard
    let mut line_spans = spans;

    if matches!(state.mode, AppMode::Executing | AppMode::Paused) {
        if let Some(feature) = &state.feature {
            let phase_info = format!(
                "Phase {}/4 ",
                feature.current_phase
            );

            // Add spacer
            let current_len: usize = line_spans.iter().map(|s| s.content.len()).sum();
            let available = area.width as usize;
            let phase_len = phase_info.len();

            if current_len + phase_len < available {
                let padding = available.saturating_sub(current_len + phase_len);
                line_spans.push(Span::raw(" ".repeat(padding)));
                line_spans.push(Span::styled(phase_info, theme.style_muted()));
            }
        }
    }

    let paragraph = Paragraph::new(Line::from(line_spans))
        .style(Style::default().bg(Color::Rgb(30, 30, 30)));

    frame.render_widget(paragraph, area);
}

use crate::model::{AppMode, AppState, Focus, OutputLevel};
use crate::ui::layout::{main_layout, sidebar_layout};
use crate::ui::widgets;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState};

/// Render the main execution dashboard
pub fn render_dashboard(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let (header, body, footer) = main_layout(area);

    // Header with feature name and status
    render_dashboard_header(frame, header, state, theme);

    // Body with sidebar and main content
    let (sidebar, main) = sidebar_layout(body);

    // Sidebar: Phase progress + Task list
    render_sidebar(frame, sidebar, state, theme);

    // Main: Output stream
    render_output_stream(frame, main, state, theme);

    // Footer: Status bar
    widgets::render_status_bar(frame, footer, state, theme);
}

fn render_dashboard_header(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let feature_name = state
        .feature
        .as_ref()
        .map(|f| f.feature_name.as_str())
        .unwrap_or("Unknown");

    let mode_name = state
        .execution_mode
        .map(|m| m.name())
        .unwrap_or("Unknown");

    let status = match state.mode {
        AppMode::Executing => ("Running", theme.style_primary()),
        AppMode::Paused => ("Paused", theme.style_warning()),
        _ => ("", Style::default()),
    };

    let completion = state
        .feature
        .as_ref()
        .map(|f| f.completion_percentage())
        .unwrap_or(0);

    let header_content = vec![
        Line::from(vec![
            Span::styled("Feature: ", theme.style_muted()),
            Span::styled(feature_name, theme.style_header()),
            Span::raw("  │  "),
            Span::styled("Mode: ", theme.style_muted()),
            Span::raw(mode_name),
            Span::raw("  │  "),
            Span::styled("Status: ", theme.style_muted()),
            Span::styled(status.0, status.1),
        ]),
        Line::from(vec![
            Span::styled("Progress: ", theme.style_muted()),
            Span::styled(format!("{}%", completion), theme.style_primary()),
        ]),
    ];

    let block = Block::default()
        .borders(Borders::BOTTOM)
        .border_style(theme.style_border());

    let paragraph = Paragraph::new(header_content)
        .block(block)
        .alignment(Alignment::Left);

    frame.render_widget(paragraph, area);
}

fn render_sidebar(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage(60), // Phases
            Constraint::Percentage(40), // Tasks
        ])
        .split(area);

    // Phase progress
    widgets::render_phase_progress(frame, chunks[0], state, theme);

    // Task list
    widgets::render_task_list(frame, chunks[1], state, theme);
}

fn render_output_stream(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let block = Block::default()
        .title(" Output ")
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(if state.ui.focus == Focus::Main {
            theme.style_border_focused()
        } else {
            theme.style_border()
        });

    let inner = block.inner(area);
    frame.render_widget(block, area);

    if state.output_buffer.is_empty() {
        let empty_msg = Paragraph::new(vec![
            Line::from(""),
            Line::from(Span::styled(
                "Waiting for output...",
                theme.style_muted(),
            )),
        ])
        .alignment(Alignment::Center);
        frame.render_widget(empty_msg, inner);
        return;
    }

    // Calculate visible lines
    let visible_height = inner.height as usize;
    let total_lines = state.output_buffer.len();
    let scroll_offset = state.ui.output_scroll.min(total_lines.saturating_sub(visible_height));

    // Create lines from output buffer
    let lines: Vec<Line> = state
        .output_buffer
        .iter()
        .skip(scroll_offset)
        .take(visible_height)
        .map(|output| {
            let style = match output.level {
                OutputLevel::Info => Style::default(),
                OutputLevel::Success => theme.style_success(),
                OutputLevel::Warning => theme.style_warning(),
                OutputLevel::Error => theme.style_error(),
                OutputLevel::Command => theme.style_primary(),
                OutputLevel::Debug => theme.style_muted(),
            };
            Line::from(Span::styled(output.content.clone(), style))
        })
        .collect();

    let paragraph = Paragraph::new(lines);
    frame.render_widget(paragraph, inner);

    // Scrollbar
    if total_lines > visible_height {
        let scrollbar = Scrollbar::default()
            .orientation(ScrollbarOrientation::VerticalRight)
            .begin_symbol(Some("↑"))
            .end_symbol(Some("↓"));

        let mut scrollbar_state = ScrollbarState::new(total_lines)
            .position(scroll_offset);

        frame.render_stateful_widget(
            scrollbar,
            area.inner(Margin {
                vertical: 1,
                horizontal: 0,
            }),
            &mut scrollbar_state,
        );
    }
}

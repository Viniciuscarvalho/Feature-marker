use crate::model::{AppState, FeatureState, PhaseStatus};
use crate::ui::layout::main_layout;
use crate::ui::widgets;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, List, ListItem, Paragraph};

/// Render the kanban board view
pub fn render_kanban(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let area = frame.area();
    let (header, body, footer) = main_layout(area);

    // Header with banner
    widgets::render_banner(frame, header, theme);

    // Title bar
    let title_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(2), Constraint::Min(0)])
        .split(body);

    let title = Paragraph::new(Line::from(vec![
        Span::styled(" Kanban Board ", theme.style_header()),
        Span::styled(
            format!(
                "— {} features",
                state.kanban_features.len()
            ),
            theme.style_muted(),
        ),
    ]));
    frame.render_widget(title, title_chunks[0]);

    // Four columns: Pending, In Progress, Blocked, Done
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(25),
            Constraint::Percentage(25),
            Constraint::Percentage(25),
            Constraint::Percentage(25),
        ])
        .split(title_chunks[1]);

    let pending: Vec<&FeatureState> = state
        .kanban_features
        .iter()
        .filter(|f| f.phase_status == PhaseStatus::Pending)
        .collect();

    let in_progress: Vec<&FeatureState> = state
        .kanban_features
        .iter()
        .filter(|f| f.phase_status == PhaseStatus::InProgress)
        .collect();

    let blocked: Vec<&FeatureState> = state
        .kanban_features
        .iter()
        .filter(|f| f.phase_status == PhaseStatus::Error)
        .collect();

    let done: Vec<&FeatureState> = state
        .kanban_features
        .iter()
        .filter(|f| f.phase_status == PhaseStatus::Completed)
        .collect();

    render_column(frame, columns[0], "Pending", &pending, theme.muted, theme);
    render_column(frame, columns[1], "In Progress", &in_progress, theme.primary, theme);
    render_column(frame, columns[2], "Blocked", &blocked, theme.error, theme);
    render_column(frame, columns[3], "Done", &done, theme.success, theme);

    // Footer
    widgets::render_status_bar(frame, footer, state, theme);
}

fn render_column(
    frame: &mut Frame,
    area: Rect,
    title: &str,
    features: &[&FeatureState],
    color: Color,
    theme: &Theme,
) {
    let block = Block::default()
        .title(format!(" {} ({}) ", title, features.len()))
        .title_style(Style::default().fg(color).add_modifier(Modifier::BOLD))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(color));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    if features.is_empty() {
        let empty = Paragraph::new(Span::styled("  —", theme.style_muted()));
        frame.render_widget(empty, inner);
        return;
    }

    let items: Vec<ListItem> = features
        .iter()
        .map(|f| {
            let symbol = f.phase_status.symbol();
            let phase_name = f
                .get_phase(f.current_phase)
                .map(|p| p.name.as_str())
                .unwrap_or("—");
            let pct = f.completion_percentage();

            let name_line = Line::from(vec![
                Span::styled(format!("{} ", symbol), Style::default().fg(color)),
                Span::styled(
                    f.feature_name.clone(),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
            ]);

            let detail_line = Line::from(vec![
                Span::raw("  "),
                Span::styled(
                    format!("{} {}%", phase_name, pct),
                    theme.style_muted(),
                ),
            ]);

            ListItem::new(vec![name_line, detail_line, Line::from("")])
        })
        .collect();

    let list = List::new(items);
    frame.render_widget(list, inner);
}

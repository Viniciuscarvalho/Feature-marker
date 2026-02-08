use crate::model::AppState;
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, List, ListItem, Paragraph};

/// Render the task list widget
pub fn render_task_list(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let block = Block::default()
        .title(" Tasks ")
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(theme.style_border());

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let Some(feature) = &state.feature else {
        let empty = Paragraph::new(Span::styled("No feature loaded", theme.style_muted()))
            .alignment(Alignment::Center);
        frame.render_widget(empty, inner);
        return;
    };

    // Get current phase
    let current_phase = feature.get_phase(feature.current_phase);

    match current_phase {
        Some(phase) if phase.total_tasks.is_some() => {
            let total = phase.total_tasks.unwrap_or(0);
            let current = phase.current_task_index.unwrap_or(0);
            let completed = &phase.completed_tasks;

            // Generate task items
            let items: Vec<ListItem> = (1..=total)
                .map(|i| {
                    let (symbol, style) = if completed.contains(&i) {
                        ("✓", theme.style_success())
                    } else if i == current {
                        ("→", theme.style_primary())
                    } else {
                        ("○", theme.style_muted())
                    };

                    ListItem::new(Line::from(vec![
                        Span::styled(format!(" {} ", symbol), style),
                        Span::styled(format!("Task {}", i), style),
                    ]))
                })
                .collect();

            let list = List::new(items);
            frame.render_widget(list, inner);
        }
        _ => {
            let msg = Paragraph::new(vec![
                Line::from(""),
                Line::from(Span::styled(
                    "No tasks in current phase",
                    theme.style_muted(),
                )),
            ])
            .alignment(Alignment::Center);
            frame.render_widget(msg, inner);
        }
    }
}

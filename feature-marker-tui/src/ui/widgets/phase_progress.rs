use crate::model::{AppState, PhaseStatus};
use crate::ui::Theme;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Gauge, List, ListItem};

/// Render the phase progress widget
pub fn render_phase_progress(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let block = Block::default()
        .title(" Phases ")
        .title_style(theme.style_header())
        .borders(Borders::ALL)
        .border_style(theme.style_border());

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let Some(feature) = &state.feature else {
        return;
    };

    // Create phase items
    let phases = [
        ("0", "Inputs Gate"),
        ("1", "Analysis & Planning"),
        ("2", "Implementation"),
        ("3", "Tests & Validation"),
        ("4", "Commit & PR"),
    ];

    let items: Vec<ListItem> = phases
        .iter()
        .map(|(num, name)| {
            let phase = feature.phases.get(*num);
            let status = phase
                .map(|p| &p.status)
                .unwrap_or(&PhaseStatus::Pending);

            let (symbol, style) = match status {
                PhaseStatus::Completed => ("✓", theme.style_success()),
                PhaseStatus::InProgress => ("→", theme.style_primary()),
                PhaseStatus::Error => ("✗", theme.style_error()),
                PhaseStatus::Pending => ("○", theme.style_muted()),
            };

            let is_current = feature.current_phase.to_string() == *num;
            let prefix_style = if is_current {
                style.add_modifier(Modifier::BOLD)
            } else {
                style
            };

            let mut lines = vec![Line::from(vec![
                Span::styled(format!(" {} ", symbol), prefix_style),
                Span::styled(format!("{}. {}", num, name), style),
            ])];

            // Add progress bar for in-progress phase with tasks
            if *status == PhaseStatus::InProgress {
                if let Some(phase) = phase {
                    if let Some((current, total)) = phase.task_progress() {
                        let progress = (current as f64 / total as f64).min(1.0);
                        let bar_width = 12;
                        let filled = (progress * bar_width as f64) as usize;
                        let empty = bar_width - filled;

                        let bar = format!(
                            "    [{}{}] {}/{}",
                            "█".repeat(filled),
                            "░".repeat(empty),
                            current,
                            total
                        );
                        lines.push(Line::from(Span::styled(bar, theme.style_primary())));
                    }
                }
            }

            ListItem::new(lines)
        })
        .collect();

    let list = List::new(items);
    frame.render_widget(list, inner);
}

/// Render a progress bar for overall completion
pub fn render_overall_progress(frame: &mut Frame, area: Rect, state: &AppState, theme: &Theme) {
    let completion = state
        .feature
        .as_ref()
        .map(|f| f.completion_percentage())
        .unwrap_or(0);

    let gauge = Gauge::default()
        .block(Block::default().title("Progress").borders(Borders::ALL))
        .gauge_style(theme.style_primary())
        .percent(completion as u16)
        .label(format!("{}%", completion));

    frame.render_widget(gauge, area);
}

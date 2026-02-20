use crate::model::{FeatureState, PhaseStatus};
use anyhow::Result;
use std::fs;
use std::path::Path;

/// Generate a kanban.md string from a list of feature states
pub fn generate_kanban_md(features: &[FeatureState]) -> String {
    let now = chrono::Utc::now().format("%Y-%m-%d %H:%M UTC");

    let mut pending = Vec::new();
    let mut in_progress = Vec::new();
    let mut blocked = Vec::new();
    let mut done = Vec::new();

    for feature in features {
        match &feature.phase_status {
            PhaseStatus::Pending => pending.push(feature),
            PhaseStatus::InProgress => in_progress.push(feature),
            PhaseStatus::Error => blocked.push(feature),
            PhaseStatus::Completed => done.push(feature),
        }
    }

    let mut out = String::new();
    out.push_str("# Feature Kanban Board\n");
    out.push_str(&format!("> Last updated: {}\n\n", now));

    out.push_str("## Pending\n");
    if pending.is_empty() {
        out.push_str("_No pending features_\n");
    } else {
        for f in &pending {
            let phase_name = f
                .get_phase(f.current_phase)
                .map(|p| p.name.as_str())
                .unwrap_or("Unknown");
            out.push_str(&format!("- [ ] **{}** — {}\n", f.feature_name, phase_name));
        }
    }
    out.push('\n');

    out.push_str("## In Progress\n");
    if in_progress.is_empty() {
        out.push_str("_No features in progress_\n");
    } else {
        for f in &in_progress {
            let phase_name = f
                .get_phase(f.current_phase)
                .map(|p| p.name.as_str())
                .unwrap_or("Unknown");
            let pct = f.completion_percentage();
            out.push_str(&format!(
                "- [→] **{}** — {} ({}%)\n",
                f.feature_name, phase_name, pct
            ));
        }
    }
    out.push('\n');

    out.push_str("## Blocked\n");
    if blocked.is_empty() {
        out.push_str("_No blocked features_\n");
    } else {
        for f in &blocked {
            let err = f
                .error_state
                .as_deref()
                .unwrap_or("Unknown error");
            out.push_str(&format!(
                "- [✗] **{}** — {}\n",
                f.feature_name, err
            ));
        }
    }
    out.push('\n');

    out.push_str("## Done\n");
    if done.is_empty() {
        out.push_str("_No completed features_\n");
    } else {
        for f in &done {
            let date = f.last_updated.format("%Y-%m-%d");
            out.push_str(&format!(
                "- [✓] **{}** — completed {}\n",
                f.feature_name, date
            ));
        }
    }

    out
}

/// Write kanban.md to the state directory
pub fn write_kanban(state_path: &Path, content: &str) -> Result<()> {
    fs::create_dir_all(state_path)?;
    let path = state_path.join("kanban.md");
    fs::write(path, content)?;
    Ok(())
}

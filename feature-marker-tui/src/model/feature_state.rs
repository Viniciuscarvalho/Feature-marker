use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

/// Represents the checkpoint.json structure from state-manager.sh
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureState {
    pub version: String,
    pub feature_name: String,
    pub project_path: PathBuf,
    pub current_phase: u8,
    pub phase_status: PhaseStatus,
    pub phases: HashMap<String, Phase>,
    pub last_updated: DateTime<Utc>,
    #[serde(default)]
    pub paused: bool,
    #[serde(default)]
    pub error_state: Option<String>,
}

impl FeatureState {
    /// Create a new feature state with default values
    pub fn new(feature_name: String, project_path: PathBuf) -> Self {
        let mut phases = HashMap::new();
        phases.insert(
            "0".to_string(),
            Phase::new("Inputs Gate".to_string()),
        );
        phases.insert(
            "1".to_string(),
            Phase::new("Analysis & Planning".to_string()),
        );
        phases.insert(
            "2".to_string(),
            Phase::new("Implementation".to_string()),
        );
        phases.insert(
            "3".to_string(),
            Phase::new("Tests & Validation".to_string()),
        );
        phases.insert(
            "4".to_string(),
            Phase::new("Commit & PR".to_string()),
        );

        Self {
            version: "1.2.0".to_string(),
            feature_name,
            project_path,
            current_phase: 0,
            phase_status: PhaseStatus::Pending,
            phases,
            last_updated: Utc::now(),
            paused: false,
            error_state: None,
        }
    }

    /// Get phase by number
    pub fn get_phase(&self, phase_num: u8) -> Option<&Phase> {
        self.phases.get(&phase_num.to_string())
    }

    /// Get mutable phase by number
    pub fn get_phase_mut(&mut self, phase_num: u8) -> Option<&mut Phase> {
        self.phases.get_mut(&phase_num.to_string())
    }

    /// Check if all phases are completed
    pub fn is_completed(&self) -> bool {
        self.phases.values().all(|p| p.status == PhaseStatus::Completed)
    }

    /// Get the next pending phase
    pub fn next_pending_phase(&self) -> Option<u8> {
        for i in 0..=4 {
            if let Some(phase) = self.get_phase(i) {
                if phase.status == PhaseStatus::Pending {
                    return Some(i);
                }
            }
        }
        None
    }

    /// Get completion percentage
    pub fn completion_percentage(&self) -> u8 {
        let completed = self
            .phases
            .values()
            .filter(|p| p.status == PhaseStatus::Completed)
            .count();
        ((completed * 100) / self.phases.len()) as u8
    }
}

/// Represents a single phase in the workflow
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Phase {
    pub name: String,
    pub status: PhaseStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completed_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_task_index: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total_tasks: Option<u32>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub completed_tasks: Vec<u32>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub outputs: Vec<String>,
}

impl Phase {
    pub fn new(name: String) -> Self {
        Self {
            name,
            status: PhaseStatus::Pending,
            started_at: None,
            completed_at: None,
            current_task_index: None,
            total_tasks: None,
            completed_tasks: Vec::new(),
            outputs: Vec::new(),
        }
    }

    /// Start the phase
    pub fn start(&mut self) {
        self.status = PhaseStatus::InProgress;
        self.started_at = Some(Utc::now());
    }

    /// Complete the phase
    pub fn complete(&mut self) {
        self.status = PhaseStatus::Completed;
        self.completed_at = Some(Utc::now());
    }

    /// Mark phase as error
    pub fn error(&mut self) {
        self.status = PhaseStatus::Error;
    }

    /// Get task progress as (current, total)
    pub fn task_progress(&self) -> Option<(u32, u32)> {
        match (self.current_task_index, self.total_tasks) {
            (Some(current), Some(total)) => Some((current, total)),
            _ => None,
        }
    }
}

/// Status of a phase
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum PhaseStatus {
    #[default]
    Pending,
    InProgress,
    Completed,
    Error,
}

impl PhaseStatus {
    /// Get display symbol for the status
    pub fn symbol(&self) -> &'static str {
        match self {
            PhaseStatus::Pending => "○",
            PhaseStatus::InProgress => "→",
            PhaseStatus::Completed => "✓",
            PhaseStatus::Error => "✗",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_new_feature_state() {
        let state = FeatureState::new(
            "test-feature".to_string(),
            PathBuf::from("/tmp/project"),
        );

        assert_eq!(state.feature_name, "test-feature");
        assert_eq!(state.current_phase, 0);
        assert_eq!(state.phases.len(), 5);
        assert!(!state.paused);
    }

    #[test]
    fn test_phase_progress() {
        let mut phase = Phase::new("Test".to_string());
        phase.current_task_index = Some(3);
        phase.total_tasks = Some(10);

        assert_eq!(phase.task_progress(), Some((3, 10)));
    }

    #[test]
    fn test_completion_percentage() {
        let mut state = FeatureState::new(
            "test".to_string(),
            PathBuf::from("/tmp"),
        );

        // Complete 2 out of 5 phases
        state.get_phase_mut(0).unwrap().complete();
        state.get_phase_mut(1).unwrap().complete();

        assert_eq!(state.completion_percentage(), 40);
    }
}

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use notify::{Config, RecommendedWatcher, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tauri::{AppHandle, Emitter};
use tokio::sync::{oneshot, Mutex};

/// Shared application state
pub struct AppState {
    /// Current project directory
    pub project_dir: Option<PathBuf>,
    /// Path to feature-marker-dist
    pub feature_marker_path: PathBuf,
    /// Currently running feature (if any)
    pub running_feature: Option<RunningFeature>,
    /// Cached feature states
    pub features: HashMap<String, FeatureState>,
    /// Output log buffer
    pub output_log: Vec<String>,
    /// Cancel sender for stopping the running process
    pub cancel_sender: Option<oneshot::Sender<()>>,
}

impl AppState {
    pub fn new() -> Result<Self> {
        // Find feature-marker-dist path
        let feature_marker_path = find_feature_marker_path()?;

        Ok(Self {
            project_dir: std::env::current_dir().ok(),
            feature_marker_path,
            running_feature: None,
            features: HashMap::new(),
            output_log: Vec::new(),
            cancel_sender: None,
        })
    }

    /// Get state directory path
    pub fn state_dir(&self) -> Option<PathBuf> {
        self.project_dir.as_ref().map(|p| p.join(".claude/feature-state"))
    }

    /// List available features
    pub fn list_features(&mut self) -> Result<Vec<FeatureSummary>> {
        let state_dir = match self.state_dir() {
            Some(dir) if dir.exists() => dir,
            _ => return Ok(Vec::new()),
        };

        let mut features = Vec::new();
        for entry in std::fs::read_dir(&state_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let checkpoint_path = path.join("checkpoint.json");
                if checkpoint_path.exists() {
                    if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                        if let Ok(state) = self.load_feature_state(name) {
                            features.push(FeatureSummary {
                                name: name.to_string(),
                                current_phase: state.current_phase,
                                total_phases: 5,
                                phase_status: format!("{:?}", state.phase_status),
                                last_updated: state.last_updated,
                                is_running: self.running_feature.as_ref()
                                    .map(|r| r.name == name)
                                    .unwrap_or(false),
                                paused: state.paused,
                                has_error: state.error_state.is_some(),
                            });
                        }
                    }
                }
            }
        }

        features.sort_by(|a, b| b.last_updated.cmp(&a.last_updated));
        Ok(features)
    }

    /// Load feature state from checkpoint
    pub fn load_feature_state(&mut self, feature: &str) -> Result<FeatureState> {
        let state_dir = self.state_dir()
            .context("No project directory set")?;

        let checkpoint_path = state_dir.join(feature).join("checkpoint.json");
        let content = std::fs::read_to_string(&checkpoint_path)
            .with_context(|| format!("Failed to read checkpoint: {}", checkpoint_path.display()))?;

        let state: FeatureState = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse checkpoint: {}", checkpoint_path.display()))?;

        self.features.insert(feature.to_string(), state.clone());
        Ok(state)
    }

    /// Add output line to log
    pub fn add_output(&mut self, line: String) {
        // Keep last 1000 lines
        if self.output_log.len() > 1000 {
            self.output_log.remove(0);
        }
        self.output_log.push(line);
    }

    /// Clear output log
    pub fn clear_output(&mut self) {
        self.output_log.clear();
    }
}

/// Find feature-marker-dist installation path
fn find_feature_marker_path() -> Result<PathBuf> {
    // Check common locations
    let candidates = [
        // User's home directory
        dirs::home_dir().map(|h| h.join(".feature-marker")),
        // XDG data directory
        dirs::data_dir().map(|d| d.join("feature-marker")),
        // Relative to this binary
        std::env::current_exe().ok().and_then(|e| e.parent().map(|p| p.to_path_buf())),
    ];

    for candidate in candidates.into_iter().flatten() {
        if candidate.join("feature-marker.sh").exists() {
            return Ok(candidate);
        }
    }

    // Default to home directory installation
    Ok(dirs::home_dir()
        .context("Could not find home directory")?
        .join(".feature-marker"))
}

/// Currently running feature
#[derive(Debug, Clone)]
pub struct RunningFeature {
    pub name: String,
    pub mode: String,
    pub started_at: DateTime<Utc>,
    pub process_id: Option<u32>,
}

/// Feature summary for listing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureSummary {
    pub name: String,
    pub current_phase: u8,
    pub total_phases: u8,
    pub phase_status: String,
    pub last_updated: DateTime<Utc>,
    pub is_running: bool,
    pub paused: bool,
    pub has_error: bool,
}

/// Full feature state (matching TUI's FeatureState)
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

/// Phase information
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

/// Phase status enum
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum PhaseStatus {
    #[default]
    Pending,
    InProgress,
    Completed,
    Error,
}

/// Watch for checkpoint file changes
pub async fn watch_checkpoints(
    app_handle: AppHandle,
    state: Arc<Mutex<AppState>>,
) -> Result<()> {
    let (tx, rx) = std::sync::mpsc::channel();

    let mut watcher = RecommendedWatcher::new(
        move |res| {
            let _ = tx.send(res);
        },
        Config::default().with_poll_interval(Duration::from_millis(500)),
    )?;

    // Initial setup - watch state directory if it exists
    {
        let state_guard = state.lock().await;
        if let Some(state_dir) = state_guard.state_dir() {
            if state_dir.exists() {
                watcher.watch(&state_dir, RecursiveMode::Recursive)?;
            }
        }
    }

    loop {
        match rx.recv_timeout(Duration::from_millis(100)) {
            Ok(Ok(event)) => {
                for path in &event.paths {
                    if path.file_name().map(|n| n == "checkpoint.json").unwrap_or(false) {
                        match event.kind {
                            notify::EventKind::Modify(_) | notify::EventKind::Create(_) => {
                                if let Some(feature_dir) = path.parent() {
                                    if let Some(feature_name) = feature_dir.file_name() {
                                        let feature = feature_name.to_string_lossy().to_string();
                                        tracing::debug!("Checkpoint updated: {}", feature);

                                        // Reload state and emit event
                                        let mut state_guard = state.lock().await;
                                        if let Ok(feature_state) = state_guard.load_feature_state(&feature) {
                                            let _ = app_handle.emit("feature-updated", &feature_state);

                                            // Check for phase completion
                                            check_phase_completion(&app_handle, &feature_state);
                                        }
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                }
            }
            Ok(Err(e)) => {
                tracing::warn!("Watcher error: {}", e);
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                // Check if we need to update watched directory
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                tracing::error!("Watcher channel disconnected");
                break;
            }
        }
    }

    Ok(())
}

/// Check for phase completion and send notification
fn check_phase_completion(app_handle: &AppHandle, state: &FeatureState) {
    let phase_names = ["Inputs Gate", "Analysis & Planning", "Implementation", "Tests & Validation", "Commit & PR"];

    for (i, name) in phase_names.iter().enumerate() {
        if let Some(phase) = state.phases.get(&i.to_string()) {
            if phase.status == PhaseStatus::Completed {
                if let Some(completed_at) = phase.completed_at {
                    // Check if this was completed recently (within 5 seconds)
                    let now = Utc::now();
                    let diff = now.signed_duration_since(completed_at);
                    if diff.num_seconds() < 5 && diff.num_seconds() >= 0 {
                        let _ = app_handle.emit("phase-completed", serde_json::json!({
                            "feature": state.feature_name,
                            "phase": i,
                            "phase_name": name,
                        }));
                    }
                }
            }
        }
    }
}

/// App configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub project_dir: Option<PathBuf>,
    pub feature_marker_path: PathBuf,
    pub notifications_enabled: bool,
}

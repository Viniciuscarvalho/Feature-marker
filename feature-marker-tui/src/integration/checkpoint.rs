use crate::model::FeatureState;
use anyhow::{Context, Result};
use std::fs;
use std::path::{Path, PathBuf};

/// Manages checkpoint files for feature state persistence
pub struct CheckpointManager {
    state_path: PathBuf,
}

impl CheckpointManager {
    /// Create a new checkpoint manager
    pub fn new(state_path: PathBuf) -> Self {
        Self { state_path }
    }

    /// Get the base state directory path
    pub fn state_path(&self) -> &PathBuf {
        &self.state_path
    }

    /// Get the state directory for a feature
    pub fn feature_dir(&self, feature: &str) -> PathBuf {
        self.state_path.join(feature)
    }

    /// Get the checkpoint file path for a feature
    pub fn checkpoint_path(&self, feature: &str) -> PathBuf {
        self.feature_dir(feature).join("checkpoint.json")
    }

    /// Check if a checkpoint exists for a feature
    pub fn exists(&self, feature: &str) -> bool {
        self.checkpoint_path(feature).exists()
    }

    /// List all features with checkpoints
    pub fn list_features(&self) -> Result<Vec<String>> {
        let mut features = Vec::new();

        if !self.state_path.exists() {
            return Ok(features);
        }

        for entry in fs::read_dir(&self.state_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                    // Check if it has a checkpoint.json
                    if path.join("checkpoint.json").exists() {
                        features.push(name.to_string());
                    }
                }
            }
        }

        features.sort();
        Ok(features)
    }

    /// Load checkpoint for a feature
    pub fn load(&self, feature: &str) -> Result<FeatureState> {
        let path = self.checkpoint_path(feature);
        let content = fs::read_to_string(&path)
            .with_context(|| format!("Failed to read checkpoint: {}", path.display()))?;

        serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse checkpoint: {}", path.display()))
    }

    /// Save checkpoint for a feature (atomic write)
    pub fn save(&self, state: &FeatureState) -> Result<()> {
        let feature_dir = self.feature_dir(&state.feature_name);
        fs::create_dir_all(&feature_dir)?;

        let checkpoint_path = self.checkpoint_path(&state.feature_name);
        let temp_path = checkpoint_path.with_extension("json.tmp");

        // Write to temp file first
        let content = serde_json::to_string_pretty(state)?;
        fs::write(&temp_path, content)?;

        // Atomic rename
        fs::rename(&temp_path, &checkpoint_path)?;

        Ok(())
    }

    /// Initialize a new feature checkpoint
    pub fn init(&self, feature: &str, project_path: &Path) -> Result<FeatureState> {
        let state = FeatureState::new(feature.to_string(), project_path.to_path_buf());
        self.save(&state)?;
        Ok(state)
    }

    /// Get summary info for a feature (without loading full state)
    pub fn get_summary(&self, feature: &str) -> Result<FeatureSummary> {
        let state = self.load(feature)?;
        Ok(FeatureSummary {
            feature_name: state.feature_name,
            current_phase: state.current_phase,
            phase_status: format!("{:?}", state.phase_status),
            last_updated: state.last_updated.format("%Y-%m-%d %H:%M").to_string(),
            paused: state.paused,
            has_error: state.error_state.is_some(),
        })
    }

    /// Read additional artifact file
    pub fn read_artifact(&self, feature: &str, filename: &str) -> Result<Option<String>> {
        let path = self.feature_dir(feature).join(filename);
        if path.exists() {
            Ok(Some(fs::read_to_string(path)?))
        } else {
            Ok(None)
        }
    }

    /// Write additional artifact file
    pub fn write_artifact(&self, feature: &str, filename: &str, content: &str) -> Result<()> {
        let path = self.feature_dir(feature).join(filename);
        fs::write(path, content)?;
        Ok(())
    }
}

/// Summary info for a feature
#[derive(Debug)]
pub struct FeatureSummary {
    pub feature_name: String,
    pub current_phase: u8,
    pub phase_status: String,
    pub last_updated: String,
    pub paused: bool,
    pub has_error: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_checkpoint_manager() {
        let temp_dir = TempDir::new().unwrap();
        let state_path = temp_dir.path().join(".claude/feature-state");
        let manager = CheckpointManager::new(state_path);

        // Initially no features
        assert!(manager.list_features().unwrap().is_empty());

        // Create a checkpoint
        let state = manager
            .init("test-feature", temp_dir.path())
            .unwrap();

        assert_eq!(state.feature_name, "test-feature");
        assert!(manager.exists("test-feature"));

        // List features
        let features = manager.list_features().unwrap();
        assert_eq!(features, vec!["test-feature"]);

        // Load checkpoint
        let loaded = manager.load("test-feature").unwrap();
        assert_eq!(loaded.feature_name, "test-feature");
    }
}

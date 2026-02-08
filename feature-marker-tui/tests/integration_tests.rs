//! Integration tests for feature-marker-tui

use std::path::PathBuf;
use tempfile::TempDir;

mod checkpoint_tests {
    use super::*;
    use std::fs;

    /// Helper to create a temporary project directory
    fn create_temp_project() -> TempDir {
        TempDir::new().expect("Failed to create temp directory")
    }

    #[test]
    fn test_checkpoint_manager_init() {
        let temp_dir = create_temp_project();
        let state_path = temp_dir.path().join(".claude/feature-state");

        // Create checkpoint manager
        let manager = feature_marker_tui::integration::CheckpointManager::new(state_path.clone());

        // No features initially
        let features = manager.list_features().unwrap();
        assert!(features.is_empty());

        // Init a feature
        let state = manager
            .init("test-feature", temp_dir.path())
            .expect("Failed to init feature");

        assert_eq!(state.feature_name, "test-feature");
        assert_eq!(state.current_phase, 0);

        // Now the feature should exist
        assert!(manager.exists("test-feature"));

        // List should contain the feature
        let features = manager.list_features().unwrap();
        assert_eq!(features, vec!["test-feature"]);
    }

    #[test]
    fn test_checkpoint_manager_save_load() {
        let temp_dir = create_temp_project();
        let state_path = temp_dir.path().join(".claude/feature-state");
        let manager = feature_marker_tui::integration::CheckpointManager::new(state_path);

        // Create and modify a feature
        let mut state = manager
            .init("my-feature", temp_dir.path())
            .expect("Failed to init");

        state.current_phase = 2;
        state.paused = true;

        // Save
        manager.save(&state).expect("Failed to save");

        // Load and verify
        let loaded = manager.load("my-feature").expect("Failed to load");
        assert_eq!(loaded.current_phase, 2);
        assert!(loaded.paused);
    }

    #[test]
    fn test_checkpoint_file_format() {
        let temp_dir = create_temp_project();
        let state_path = temp_dir.path().join(".claude/feature-state");
        let manager = feature_marker_tui::integration::CheckpointManager::new(state_path.clone());

        manager
            .init("json-test", temp_dir.path())
            .expect("Failed to init");

        // Read raw JSON file
        let checkpoint_path = state_path.join("json-test/checkpoint.json");
        let content = fs::read_to_string(&checkpoint_path).expect("Failed to read file");

        // Should be valid JSON
        let json: serde_json::Value = serde_json::from_str(&content).expect("Invalid JSON");

        // Check required fields
        assert!(json.get("version").is_some());
        assert!(json.get("feature_name").is_some());
        assert!(json.get("current_phase").is_some());
        assert!(json.get("phases").is_some());
    }
}

mod model_tests {
    use feature_marker_tui::model::{AppMode, AppState, ExecutionMode, OutputLine, PhaseStatus};
    use std::path::PathBuf;

    #[test]
    fn test_app_state_creation() {
        let state = AppState::new(PathBuf::from("/tmp/project"));
        assert_eq!(state.mode, AppMode::Welcome);
        assert!(state.feature.is_none());
        assert!(state.execution_mode.is_none());
    }

    #[test]
    fn test_execution_mode_parsing() {
        assert_eq!(
            ExecutionMode::from_str("full"),
            Some(ExecutionMode::Full)
        );
        assert_eq!(
            ExecutionMode::from_str("tasks-only"),
            Some(ExecutionMode::TasksOnly)
        );
        assert_eq!(
            ExecutionMode::from_str("ralph-loop"),
            Some(ExecutionMode::RalphLoop)
        );
        assert_eq!(
            ExecutionMode::from_str("spec-driven"),
            Some(ExecutionMode::SpecDriven)
        );
        assert_eq!(ExecutionMode::from_str("invalid"), None);
    }

    #[test]
    fn test_output_buffer() {
        let mut state = AppState::new(PathBuf::from("/tmp"));

        // Add some output
        state.add_output(OutputLine::info("Test message"));
        state.add_output(OutputLine::warning("Warning message"));

        assert_eq!(state.output_buffer.len(), 2);

        // Clear
        state.clear_output();
        assert!(state.output_buffer.is_empty());
    }

    #[test]
    fn test_ui_navigation() {
        let mut state = AppState::new(PathBuf::from("/tmp"));

        // Test selection
        state.ui.select_down(5);
        assert_eq!(state.ui.selected_index, 1);

        state.ui.select_down(5);
        assert_eq!(state.ui.selected_index, 2);

        state.ui.select_up(5);
        assert_eq!(state.ui.selected_index, 1);

        // Wrap around
        state.ui.selected_index = 0;
        state.ui.select_up(5);
        assert_eq!(state.ui.selected_index, 4);
    }

    #[test]
    fn test_phase_status_values() {
        assert_eq!(PhaseStatus::default(), PhaseStatus::Pending);
    }
}

mod feature_state_tests {
    use feature_marker_tui::model::{FeatureState, PhaseStatus};
    use std::path::PathBuf;

    #[test]
    fn test_new_feature_state() {
        let state = FeatureState::new("test".to_string(), PathBuf::from("/tmp"));

        assert_eq!(state.feature_name, "test");
        assert_eq!(state.current_phase, 0);
        assert_eq!(state.phases.len(), 5);
        assert!(!state.paused);
        assert!(state.error_state.is_none());
    }

    #[test]
    fn test_phase_completion() {
        let mut state = FeatureState::new("test".to_string(), PathBuf::from("/tmp"));

        // Complete phases
        state.get_phase_mut(0).unwrap().complete();
        state.get_phase_mut(1).unwrap().complete();

        assert_eq!(state.get_phase(0).unwrap().status, PhaseStatus::Completed);
        assert_eq!(state.get_phase(1).unwrap().status, PhaseStatus::Completed);
        assert_eq!(state.get_phase(2).unwrap().status, PhaseStatus::Pending);

        // Check percentage
        assert_eq!(state.completion_percentage(), 40);
    }

    #[test]
    fn test_all_phases_completed() {
        let mut state = FeatureState::new("test".to_string(), PathBuf::from("/tmp"));

        for i in 0..=4 {
            state.get_phase_mut(i).unwrap().complete();
        }

        assert!(state.is_completed());
        assert_eq!(state.completion_percentage(), 100);
    }
}

mod config_tests {
    use feature_marker_tui::config::{load_config, AppConfig};
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_default_config() {
        let temp_dir = TempDir::new().unwrap();
        let config = load_config(temp_dir.path()).unwrap();

        assert_eq!(config.docs_path.to_str().unwrap(), "./tasks");
        assert_eq!(
            config.state_path.to_str().unwrap(),
            ".claude/feature-state"
        );
        assert!(!config.skip_pr);
    }

    #[test]
    fn test_load_custom_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join(".feature-marker.json");

        fs::write(
            &config_path,
            r#"{
                "docs_path": "./custom/docs",
                "skip_pr": true,
                "test_command": "npm run test:ci"
            }"#,
        )
        .unwrap();

        let config = load_config(temp_dir.path()).unwrap();

        assert_eq!(config.docs_path.to_str().unwrap(), "./custom/docs");
        assert!(config.skip_pr);
        assert_eq!(config.test_command, Some("npm run test:ci".to_string()));
    }
}

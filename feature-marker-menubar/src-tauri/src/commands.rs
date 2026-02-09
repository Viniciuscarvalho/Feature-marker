use crate::process_manager;
use crate::state::{AppConfig, AppState, FeatureState, FeatureSummary, RunningFeature};
use chrono::Utc;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;

/// Get list of available features
#[tauri::command]
pub async fn get_features(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<Vec<FeatureSummary>, String> {
    let mut state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
    state_guard.list_features().map_err(|e: anyhow::Error| e.to_string())
}

/// Get detailed state of a specific feature
#[tauri::command]
pub async fn get_feature_state(
    state: State<'_, Arc<Mutex<AppState>>>,
    feature: String,
) -> Result<FeatureState, String> {
    let mut state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
    state_guard.load_feature_state(&feature).map_err(|e: anyhow::Error| e.to_string())
}

/// Start a new feature workflow - spawns claude as child process
#[tauri::command]
pub async fn start_feature(
    app: AppHandle,
    state: State<'_, Arc<Mutex<AppState>>>,
    feature: String,
    mode: Option<String>,
) -> Result<(), String> {
    let mode = mode.unwrap_or_else(|| "full".to_string());

    // Check if there's already a running feature
    {
        let state_guard = state.lock().await;
        if state_guard.running_feature.is_some() {
            return Err("A feature is already running. Please wait or cancel it first.".to_string());
        }
    }

    // Get project directory
    let project_dir = {
        let state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
        state_guard.project_dir.clone()
    };

    let project_dir = project_dir.ok_or("No project directory set. Please set a project directory first via Settings.")?;

    if !project_dir.exists() {
        return Err(format!("Project directory does not exist: {}", project_dir.display()));
    }

    // Set running feature
    {
        let mut state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
        state_guard.running_feature = Some(RunningFeature {
            name: feature.clone(),
            mode: mode.clone(),
            started_at: Utc::now(),
            process_id: None, // Will be set by process_manager
        });
        state_guard.clear_output();
    }

    // Add initial output
    {
        let mut state_guard = state.lock().await;
        state_guard.add_output(format!("Starting feature: {}", feature));
        state_guard.add_output(format!("Mode: {}", mode));
        state_guard.add_output(format!("Project: {}", project_dir.display()));
        state_guard.add_output("".to_string());
    }

    // Emit initial output lines to UI
    let _ = app.emit("output-line", format!("Starting feature: {}", feature));
    let _ = app.emit("output-line", format!("Mode: {}", mode));
    let _ = app.emit("output-line", format!("Project: {}", project_dir.display()));
    let _ = app.emit("output-line", "");

    tracing::info!("Starting feature {} in mode {} for project {}", feature, mode, project_dir.display());

    // Spawn the claude process
    let state_arc = state.inner().clone();
    match process_manager::spawn_claude_process(
        app.clone(),
        state_arc,
        project_dir,
        feature.clone(),
        mode,
    ).await {
        Ok(pid) => {
            tracing::info!("Claude process spawned with PID: {}", pid);
            let _ = app.emit("feature-started", &feature);
            let _ = app.emit("output-line", format!("Process started (PID: {})", pid));
            Ok(())
        }
        Err(e) => {
            // Clear running feature on error
            let mut state_guard = state.lock().await;
            state_guard.running_feature = None;
            Err(format!("Failed to start feature: {}", e))
        }
    }
}

/// Resume a paused feature
#[tauri::command]
pub async fn resume_feature(
    app: AppHandle,
    state: State<'_, Arc<Mutex<AppState>>>,
    feature: String,
) -> Result<(), String> {
    start_feature(app, state, feature, Some("full".to_string())).await
}

/// Pause the currently running feature (currently acts as cancel since Claude doesn't support pause)
#[tauri::command]
pub async fn pause_feature(
    app: AppHandle,
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<(), String> {
    // For now, pause acts the same as cancel since we can't pause the Claude process
    // The feature state is maintained in checkpoint files and can be resumed later
    let state_guard = state.lock().await;

    if let Some(ref running) = state_guard.running_feature {
        let _ = app.emit("feature-paused", &running.name);
        drop(state_guard);

        // Add output
        {
            let mut state_guard = state.lock().await;
            state_guard.add_output("Feature paused. Progress is saved in checkpoint.".to_string());
        }
        let _ = app.emit("output-line", "Feature paused. Progress is saved in checkpoint.");

        // Cancel the running process
        cancel_feature(app, state).await
    } else {
        Err("No feature is currently running".to_string())
    }
}

/// Cancel the currently running feature
#[tauri::command]
pub async fn cancel_feature(
    app: AppHandle,
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<(), String> {
    let (running_feature, cancel_sender) = {
        let mut state_guard = state.lock().await;

        let running = state_guard.running_feature.clone();
        let sender = state_guard.cancel_sender.take();

        (running, sender)
    };

    if let Some(running) = running_feature {
        // Send cancellation signal
        if let Some(sender) = cancel_sender {
            let _ = sender.send(());
            tracing::info!("Sent cancellation signal for feature: {}", running.name);
        } else if let Some(pid) = running.process_id {
            // Fallback: kill process directly if no cancel sender
            let _ = process_manager::kill_process(pid).await;
            tracing::info!("Killed process {} for feature: {}", pid, running.name);
        }

        // Add to output log
        {
            let mut state_guard = state.lock().await;
            state_guard.add_output("Cancelling feature...".to_string());
        }

        let _ = app.emit("output-line", "Cancelling feature...");

        Ok(())
    } else {
        Err("No feature is currently running".to_string())
    }
}

/// Get output log
#[tauri::command]
pub async fn get_output_log(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<Vec<String>, String> {
    let state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
    Ok(state_guard.output_log.clone())
}

/// Open project directory in system file manager
#[tauri::command]
pub async fn open_project_dir(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<(), String> {
    let state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;

    if let Some(project_dir) = &state_guard.project_dir {
        #[cfg(target_os = "macos")]
        {
            let _ = std::process::Command::new("open")
                .arg(project_dir)
                .spawn();
        }

        #[cfg(target_os = "linux")]
        {
            let _ = std::process::Command::new("xdg-open")
                .arg(project_dir)
                .spawn();
        }

        Ok(())
    } else {
        Err("No project directory set".to_string())
    }
}

/// Get app configuration
#[tauri::command]
pub async fn get_app_config(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<AppConfig, String> {
    let state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
    Ok(AppConfig {
        project_dir: state_guard.project_dir.clone(),
        feature_marker_path: state_guard.feature_marker_path.clone(),
        notifications_enabled: true,
    })
}

/// Set project directory
#[tauri::command]
pub async fn set_project_dir(
    state: State<'_, Arc<Mutex<AppState>>>,
    path: String,
) -> Result<(), String> {
    let path = PathBuf::from(path);

    if !path.exists() {
        return Err("Directory does not exist".to_string());
    }

    if !path.is_dir() {
        return Err("Path is not a directory".to_string());
    }

    let mut state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;
    state_guard.project_dir = Some(path);

    Ok(())
}

/// Open terminal in project directory
#[tauri::command]
pub async fn open_terminal(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<(), String> {
    let state_guard: tokio::sync::MutexGuard<'_, AppState> = state.lock().await;

    let project_dir = state_guard.project_dir.clone()
        .ok_or("No project directory set")?;

    #[cfg(target_os = "macos")]
    {
        let apple_script = format!(
            r#"tell application "Terminal"
                activate
                do script "cd '{}'"
            end tell"#,
            project_dir.display()
        );

        std::process::Command::new("osascript")
            .arg("-e")
            .arg(&apple_script)
            .spawn()
            .map_err(|e| format!("Failed to open terminal: {}", e))?;
    }

    Ok(())
}

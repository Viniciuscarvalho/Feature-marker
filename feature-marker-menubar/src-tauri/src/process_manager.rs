use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::{Child, Command};
use tokio::sync::{oneshot, Mutex};

use crate::state::AppState;

/// Result of starting a process
#[allow(dead_code)]
pub struct ProcessHandle {
    pub child: Child,
    pub cancel_tx: oneshot::Sender<()>,
}

/// Spawn the claude command as a child process with output streaming
pub async fn spawn_claude_process(
    app_handle: AppHandle,
    state: Arc<Mutex<AppState>>,
    project_dir: PathBuf,
    feature: String,
    mode: String,
) -> Result<u32, String> {
    // Create cancellation channel
    let (cancel_tx, cancel_rx) = oneshot::channel::<()>();

    // Build the command
    // We need to source the cargo env first to ensure claude is in PATH
    let shell_command = format!(
        "source $HOME/.cargo/env 2>/dev/null; cd '{}' && claude --dangerously-skip-permissions '/feature-marker --mode {} {}'",
        project_dir.display(),
        mode,
        feature
    );

    tracing::info!("Spawning claude process: {}", shell_command);

    let mut child = Command::new("sh")
        .arg("-c")
        .arg(&shell_command)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| format!("Failed to spawn process: {}", e))?;

    let pid = child.id().ok_or("Failed to get process ID")?;

    // Store PID in state
    {
        let mut state_guard = state.lock().await;
        if let Some(ref mut running) = state_guard.running_feature {
            running.process_id = Some(pid);
        }
    }

    // Store cancel sender in state
    {
        let mut state_guard = state.lock().await;
        state_guard.cancel_sender = Some(cancel_tx);
    }

    // Take stdout and stderr
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();

    // Spawn background task to read stdout
    let app_handle_stdout = app_handle.clone();
    let state_stdout = state.clone();
    let feature_stdout = feature.clone();

    if let Some(stdout) = stdout {
        tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();

            while let Ok(Some(line)) = lines.next_line().await {
                // Emit to UI
                let _ = app_handle_stdout.emit("output-line", &line);

                // Store in state
                let mut state_guard = state_stdout.lock().await;
                state_guard.add_output(line);
            }

            tracing::debug!("stdout reader finished for feature: {}", feature_stdout);
        });
    }

    // Spawn background task to read stderr
    let app_handle_stderr = app_handle.clone();
    let state_stderr = state.clone();
    let feature_stderr = feature.clone();

    if let Some(stderr) = stderr {
        tokio::spawn(async move {
            let reader = BufReader::new(stderr);
            let mut lines = reader.lines();

            while let Ok(Some(line)) = lines.next_line().await {
                let stderr_line = format!("[stderr] {}", line);

                // Emit to UI
                let _ = app_handle_stderr.emit("output-line", &stderr_line);

                // Store in state
                let mut state_guard = state_stderr.lock().await;
                state_guard.add_output(stderr_line);
            }

            tracing::debug!("stderr reader finished for feature: {}", feature_stderr);
        });
    }

    // Spawn background task to wait for process completion or cancellation
    let app_handle_wait = app_handle.clone();
    let state_wait = state.clone();
    let feature_wait = feature.clone();

    tokio::spawn(async move {
        tokio::select! {
            // Process completed naturally
            result = child.wait() => {
                match result {
                    Ok(status) => {
                        let msg = if status.success() {
                            format!("Feature '{}' completed successfully", feature_wait)
                        } else {
                            format!("Feature '{}' exited with status: {}", feature_wait, status)
                        };

                        tracing::info!("{}", msg);

                        // Emit completion event
                        let _ = app_handle_wait.emit("output-line", &msg);

                        if status.success() {
                            let _ = app_handle_wait.emit("feature-completed", &feature_wait);
                        } else {
                            let _ = app_handle_wait.emit("feature-error", serde_json::json!({
                                "feature": feature_wait,
                                "error": format!("Process exited with status: {}", status)
                            }));
                        }
                    }
                    Err(e) => {
                        tracing::error!("Error waiting for process: {}", e);
                        let _ = app_handle_wait.emit("feature-error", serde_json::json!({
                            "feature": feature_wait,
                            "error": e.to_string()
                        }));
                    }
                }

                // Clear running feature
                let mut state_guard = state_wait.lock().await;
                state_guard.running_feature = None;
                state_guard.cancel_sender = None;
            }

            // Cancellation requested
            _ = cancel_rx => {
                tracing::info!("Cancellation requested for feature: {}", feature_wait);

                // Kill the process
                let _ = child.kill().await;

                let msg = format!("Feature '{}' was cancelled", feature_wait);
                let _ = app_handle_wait.emit("output-line", &msg);
                let _ = app_handle_wait.emit("feature-cancelled", &feature_wait);

                // Clear running feature
                let mut state_guard = state_wait.lock().await;
                state_guard.running_feature = None;
                state_guard.cancel_sender = None;
            }
        }
    });

    Ok(pid)
}

/// Kill a process by PID
pub async fn kill_process(pid: u32) -> Result<(), String> {
    #[cfg(unix)]
    {
        // Send SIGTERM first for graceful shutdown
        let result = std::process::Command::new("kill")
            .arg("-TERM")
            .arg(pid.to_string())
            .status();

        match result {
            Ok(status) if status.success() => {
                tracing::info!("Sent SIGTERM to process {}", pid);
                Ok(())
            }
            _ => {
                // If SIGTERM fails, try SIGKILL
                let result = std::process::Command::new("kill")
                    .arg("-9")
                    .arg(pid.to_string())
                    .status();

                match result {
                    Ok(status) if status.success() => {
                        tracing::info!("Sent SIGKILL to process {}", pid);
                        Ok(())
                    }
                    _ => Err(format!("Failed to kill process {}", pid)),
                }
            }
        }
    }

    #[cfg(not(unix))]
    {
        Err("Process killing is only supported on Unix systems".to_string())
    }
}

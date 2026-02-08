use anyhow::Result;
use std::path::Path;
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::mpsc;

/// Shell command executor with streaming output
pub struct ShellExecutor {
    /// Channel sender for output lines
    output_tx: mpsc::Sender<String>,
    /// Working directory
    working_dir: std::path::PathBuf,
}

impl ShellExecutor {
    /// Create a new shell executor
    pub fn new(working_dir: std::path::PathBuf, output_tx: mpsc::Sender<String>) -> Self {
        Self {
            output_tx,
            working_dir,
        }
    }

    /// Execute a command with streaming output
    pub async fn execute(&self, command: &str) -> Result<i32> {
        let _ = self
            .output_tx
            .send(format!("$ {}", command))
            .await;

        let mut child = Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(&self.working_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        let stdout = child.stdout.take().expect("Failed to capture stdout");
        let stderr = child.stderr.take().expect("Failed to capture stderr");

        let tx1 = self.output_tx.clone();
        let tx2 = self.output_tx.clone();

        // Stream stdout
        let stdout_handle = tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                let _ = tx1.send(line).await;
            }
        });

        // Stream stderr
        let stderr_handle = tokio::spawn(async move {
            let reader = BufReader::new(stderr);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                let _ = tx2.send(format!("[stderr] {}", line)).await;
            }
        });

        // Wait for streams to complete
        let _ = tokio::join!(stdout_handle, stderr_handle);

        // Wait for process to complete
        let status = child.wait().await?;
        Ok(status.code().unwrap_or(-1))
    }

    /// Execute feature-marker.sh with specific mode
    pub async fn invoke_feature_marker(
        &self,
        feature: &str,
        mode: &str,
        feature_marker_path: &Path,
    ) -> Result<i32> {
        let script = feature_marker_path.join("feature-marker.sh");
        let command = format!(
            "{} --feature {} --mode {}",
            script.display(),
            feature,
            mode
        );
        self.execute(&command).await
    }

    /// Run tests using auto-detected test command
    pub async fn run_tests(&self, custom_command: Option<&str>) -> Result<i32> {
        let command = if let Some(cmd) = custom_command {
            cmd.to_string()
        } else {
            self.detect_test_command().await
        };

        self.execute(&command).await
    }

    /// Auto-detect the test command based on project files
    async fn detect_test_command(&self) -> String {
        // Check for package.json (Node.js)
        if self.working_dir.join("package.json").exists() {
            return "npm test".to_string();
        }

        // Check for Cargo.toml (Rust)
        if self.working_dir.join("Cargo.toml").exists() {
            return "cargo test".to_string();
        }

        // Check for Package.swift (Swift)
        if self.working_dir.join("Package.swift").exists() {
            return "swift test".to_string();
        }

        // Check for pyproject.toml or setup.py (Python)
        if self.working_dir.join("pyproject.toml").exists()
            || self.working_dir.join("setup.py").exists()
        {
            return "pytest".to_string();
        }

        // Check for go.mod (Go)
        if self.working_dir.join("go.mod").exists() {
            return "go test ./...".to_string();
        }

        // Default
        "echo 'No test command detected'".to_string()
    }
}

/// Create a channel for receiving shell output
pub fn create_output_channel() -> (mpsc::Sender<String>, mpsc::Receiver<String>) {
    mpsc::channel(100)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_execute_command() {
        let (tx, mut rx) = create_output_channel();
        let executor = ShellExecutor::new(std::env::current_dir().unwrap(), tx);

        let status = executor.execute("echo 'Hello, World!'").await.unwrap();
        assert_eq!(status, 0);

        // Check output was captured
        let mut outputs = Vec::new();
        while let Ok(line) = rx.try_recv() {
            outputs.push(line);
        }
        assert!(outputs.iter().any(|l| l.contains("Hello, World!")));
    }
}

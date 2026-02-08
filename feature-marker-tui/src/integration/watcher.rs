use anyhow::Result;
use notify::{Config, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::PathBuf;
use std::sync::mpsc as std_mpsc;
use std::time::Duration;

/// File watcher for checkpoint changes
pub struct CheckpointWatcher {
    _watcher: RecommendedWatcher,
    receiver: std_mpsc::Receiver<notify::Result<notify::Event>>,
}

impl CheckpointWatcher {
    /// Create a new checkpoint watcher
    pub fn new(state_path: PathBuf) -> Result<Self> {
        let (tx, rx) = std_mpsc::channel();

        let mut watcher = RecommendedWatcher::new(
            move |res| {
                let _ = tx.send(res);
            },
            Config::default().with_poll_interval(Duration::from_millis(500)),
        )?;

        // Watch the state directory
        if state_path.exists() {
            watcher.watch(&state_path, RecursiveMode::Recursive)?;
        }

        Ok(Self {
            _watcher: watcher,
            receiver: rx,
        })
    }

    /// Check for checkpoint file changes (non-blocking)
    pub fn poll_changes(&self) -> Option<CheckpointChange> {
        match self.receiver.try_recv() {
            Ok(Ok(event)) => {
                // Check if it's a checkpoint.json modification
                for path in &event.paths {
                    if path.file_name().map(|n| n == "checkpoint.json").unwrap_or(false) {
                        match event.kind {
                            notify::EventKind::Modify(_) | notify::EventKind::Create(_) => {
                                // Extract feature name from path
                                if let Some(feature_dir) = path.parent() {
                                    if let Some(feature_name) = feature_dir.file_name() {
                                        return Some(CheckpointChange::Modified(
                                            feature_name.to_string_lossy().to_string(),
                                        ));
                                    }
                                }
                            }
                            notify::EventKind::Remove(_) => {
                                if let Some(feature_dir) = path.parent() {
                                    if let Some(feature_name) = feature_dir.file_name() {
                                        return Some(CheckpointChange::Deleted(
                                            feature_name.to_string_lossy().to_string(),
                                        ));
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                }
                None
            }
            _ => None,
        }
    }
}

/// Type of checkpoint change
#[derive(Debug, Clone)]
pub enum CheckpointChange {
    Modified(String),
    Deleted(String),
}

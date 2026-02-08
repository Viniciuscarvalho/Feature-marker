use crossterm::event::KeyCode;

/// Application events
#[derive(Debug, Clone)]
pub enum AppEvent {
    /// Keyboard input
    Key(KeyCode),
    /// Terminal resize
    Resize(u16, u16),
    /// Tick for animations/updates
    Tick,
    /// Checkpoint file changed externally
    CheckpointChanged,
    /// Command output received
    Output(String),
    /// Command completed
    CommandCompleted(i32),
    /// Phase completed
    PhaseCompleted(u8),
    /// Error occurred
    Error(String),
    /// Quit request
    Quit,
}

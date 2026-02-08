use super::FeatureState;
use std::collections::VecDeque;
use std::path::PathBuf;

/// Main application state
#[derive(Debug)]
pub struct AppState {
    /// Current application mode/screen
    pub mode: AppMode,
    /// Currently loaded feature state
    pub feature: Option<FeatureState>,
    /// Selected execution mode
    pub execution_mode: Option<ExecutionMode>,
    /// Output buffer for command output
    pub output_buffer: VecDeque<OutputLine>,
    /// UI-specific state
    pub ui: UIState,
    /// Project directory
    pub project_dir: PathBuf,
    /// Available features (for selection screen)
    pub available_features: Vec<String>,
}

impl AppState {
    pub fn new(project_dir: PathBuf) -> Self {
        Self {
            mode: AppMode::Welcome,
            feature: None,
            execution_mode: None,
            output_buffer: VecDeque::with_capacity(1000),
            ui: UIState::default(),
            project_dir,
            available_features: Vec::new(),
        }
    }

    /// Add output line to buffer
    pub fn add_output(&mut self, line: OutputLine) {
        if self.output_buffer.len() >= 1000 {
            self.output_buffer.pop_front();
        }
        self.output_buffer.push_back(line);

        // Auto-scroll to bottom if enabled
        if self.ui.auto_scroll {
            self.ui.output_scroll = self.output_buffer.len().saturating_sub(1);
        }
    }

    /// Clear output buffer
    pub fn clear_output(&mut self) {
        self.output_buffer.clear();
        self.ui.output_scroll = 0;
    }

    /// Navigate to next screen based on current mode
    pub fn navigate_next(&mut self) {
        self.mode = match &self.mode {
            AppMode::Welcome => AppMode::FeatureSelection,
            AppMode::FeatureSelection => AppMode::ModeSelection,
            AppMode::ModeSelection => AppMode::Executing,
            _ => return,
        };
    }

    /// Navigate back to previous screen
    pub fn navigate_back(&mut self) {
        self.mode = match &self.mode {
            AppMode::FeatureSelection => AppMode::Welcome,
            AppMode::ModeSelection => AppMode::FeatureSelection,
            AppMode::Paused => AppMode::Executing,
            AppMode::Error(_) => AppMode::Executing,
            _ => return,
        };
    }
}

/// Current application mode/screen
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppMode {
    /// Welcome screen with banner
    Welcome,
    /// Feature selection (new or resume)
    FeatureSelection,
    /// Execution mode selection
    ModeSelection,
    /// Main execution dashboard
    Executing,
    /// Execution paused
    Paused,
    /// Workflow completed
    Completed,
    /// Error state with message
    Error(String),
    /// Quitting
    Quitting,
}

/// Execution mode for feature-marker
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionMode {
    /// Full workflow: generate missing files + all phases
    Full,
    /// Tasks only: skip generation, use existing files
    TasksOnly,
    /// Ralph Loop: autonomous self-correcting execution
    RalphLoop,
    /// Spec-Driven: multi-agent review + isolated worktrees
    SpecDriven,
}

impl ExecutionMode {
    /// Get display name
    pub fn name(&self) -> &'static str {
        match self {
            ExecutionMode::Full => "Full Workflow",
            ExecutionMode::TasksOnly => "Tasks Only",
            ExecutionMode::RalphLoop => "Ralph Loop",
            ExecutionMode::SpecDriven => "Spec-Driven",
        }
    }

    /// Get description
    pub fn description(&self) -> &'static str {
        match self {
            ExecutionMode::Full => "Generate missing files + execute all 5 phases",
            ExecutionMode::TasksOnly => "Skip generation, use existing files",
            ExecutionMode::RalphLoop => "Autonomous self-correcting execution",
            ExecutionMode::SpecDriven => "Multi-agent review + isolated worktrees",
        }
    }

    /// Get all modes
    pub fn all() -> [ExecutionMode; 4] {
        [
            ExecutionMode::Full,
            ExecutionMode::TasksOnly,
            ExecutionMode::RalphLoop,
            ExecutionMode::SpecDriven,
        ]
    }

    /// Parse from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "full" => Some(ExecutionMode::Full),
            "tasks-only" | "tasksonly" => Some(ExecutionMode::TasksOnly),
            "ralph-loop" | "ralphloop" => Some(ExecutionMode::RalphLoop),
            "spec-driven" | "specdriven" => Some(ExecutionMode::SpecDriven),
            _ => None,
        }
    }
}

/// UI-specific state
#[derive(Debug, Default)]
pub struct UIState {
    /// Currently selected menu index
    pub selected_index: usize,
    /// Output scroll position
    pub output_scroll: usize,
    /// Auto-scroll enabled
    pub auto_scroll: bool,
    /// Show help overlay
    pub show_help: bool,
    /// Current focus (for multi-pane)
    pub focus: Focus,
    /// Feature name input buffer
    pub input_buffer: String,
    /// Is in input mode
    pub input_mode: bool,
}

impl UIState {
    /// Move selection up
    pub fn select_up(&mut self, max: usize) {
        if self.selected_index > 0 {
            self.selected_index -= 1;
        } else {
            self.selected_index = max.saturating_sub(1);
        }
    }

    /// Move selection down
    pub fn select_down(&mut self, max: usize) {
        if self.selected_index < max.saturating_sub(1) {
            self.selected_index += 1;
        } else {
            self.selected_index = 0;
        }
    }

    /// Scroll output up
    pub fn scroll_up(&mut self, amount: usize) {
        self.output_scroll = self.output_scroll.saturating_sub(amount);
        self.auto_scroll = false;
    }

    /// Scroll output down
    pub fn scroll_down(&mut self, max: usize, amount: usize) {
        self.output_scroll = (self.output_scroll + amount).min(max.saturating_sub(1));
    }

    /// Toggle auto-scroll
    pub fn toggle_auto_scroll(&mut self) {
        self.auto_scroll = !self.auto_scroll;
    }
}

/// Focus area in multi-pane layout
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Focus {
    #[default]
    Sidebar,
    Main,
}

impl Focus {
    pub fn toggle(&mut self) {
        *self = match self {
            Focus::Sidebar => Focus::Main,
            Focus::Main => Focus::Sidebar,
        };
    }
}

/// A single line of output
#[derive(Debug, Clone)]
pub struct OutputLine {
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub level: OutputLevel,
    pub content: String,
    pub source: OutputSource,
}

impl OutputLine {
    pub fn new(level: OutputLevel, content: String, source: OutputSource) -> Self {
        Self {
            timestamp: chrono::Utc::now(),
            level,
            content,
            source,
        }
    }

    pub fn info(content: impl Into<String>) -> Self {
        Self::new(OutputLevel::Info, content.into(), OutputSource::System)
    }

    pub fn success(content: impl Into<String>) -> Self {
        Self::new(OutputLevel::Success, content.into(), OutputSource::System)
    }

    pub fn warning(content: impl Into<String>) -> Self {
        Self::new(OutputLevel::Warning, content.into(), OutputSource::System)
    }

    pub fn error(content: impl Into<String>) -> Self {
        Self::new(OutputLevel::Error, content.into(), OutputSource::System)
    }

    pub fn command(content: impl Into<String>) -> Self {
        Self::new(OutputLevel::Command, content.into(), OutputSource::Shell)
    }
}

/// Output level for coloring
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutputLevel {
    Info,
    Success,
    Warning,
    Error,
    Command,
    Debug,
}

/// Source of output
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutputSource {
    System,
    Shell,
    Agent,
}

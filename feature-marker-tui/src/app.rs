use feature_marker_tui::config::AppConfig;
use feature_marker_tui::integration::{
    create_output_channel, kanban, CheckpointChange, CheckpointManager, CheckpointWatcher,
    ShellExecutor,
};
use feature_marker_tui::model::{AppMode, AppState, ExecutionMode, OutputLine, PhaseStatus};
use feature_marker_tui::ui::{render_layout, Theme};
use anyhow::Result;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio::sync::Mutex;

/// Main application
pub struct App {
    /// Application state
    state: AppState,
    /// Configuration
    config: AppConfig,
    /// Theme
    theme: Theme,
    /// Checkpoint manager
    checkpoint_manager: CheckpointManager,
    /// Checkpoint watcher
    checkpoint_watcher: Option<CheckpointWatcher>,
    /// Terminal backend
    terminal: Terminal<CrosstermBackend<std::io::Stdout>>,
    /// Shell output receiver
    shell_output_rx: Option<mpsc::Receiver<String>>,
    /// Shell executor (wrapped for async)
    shell_executor: Option<Arc<ShellExecutor>>,
    /// Feature-marker installation path
    feature_marker_path: Option<PathBuf>,
    /// Execution task handle
    execution_handle: Option<tokio::task::JoinHandle<Result<i32>>>,
    /// Flag indicating if execution is running
    is_executing: Arc<Mutex<bool>>,
}

impl App {
    /// Create a new application
    pub fn new(
        config: AppConfig,
        project_dir: PathBuf,
        initial_feature: Option<String>,
        initial_mode: Option<String>,
    ) -> Result<Self> {
        // Setup terminal
        crossterm::terminal::enable_raw_mode()?;
        let mut stdout = std::io::stdout();
        crossterm::execute!(
            stdout,
            crossterm::terminal::EnterAlternateScreen,
            crossterm::event::EnableMouseCapture
        )?;
        let backend = CrosstermBackend::new(stdout);
        let terminal = Terminal::new(backend)?;

        // Create state
        let mut state = AppState::new(project_dir.clone());

        // Create checkpoint manager
        let state_path = project_dir.join(&config.state_path);
        let checkpoint_manager = CheckpointManager::new(state_path.clone());

        // Create checkpoint watcher
        let checkpoint_watcher = CheckpointWatcher::new(state_path).ok();

        // Load available features
        state.available_features = checkpoint_manager.list_features().unwrap_or_default();

        // Find feature-marker installation
        let feature_marker_path = Self::find_feature_marker_path();

        // Handle initial feature if provided
        if let Some(feature_name) = initial_feature {
            if checkpoint_manager.exists(&feature_name) {
                state.feature = Some(checkpoint_manager.load(&feature_name)?);
            } else {
                state.feature = Some(checkpoint_manager.init(&feature_name, &project_dir)?);
            }

            // Skip to mode selection or execution
            if let Some(mode_str) = initial_mode {
                if let Some(mode) = ExecutionMode::from_str(&mode_str) {
                    state.execution_mode = Some(mode);
                    state.mode = AppMode::Executing;
                } else {
                    state.mode = AppMode::ModeSelection;
                }
            } else {
                state.mode = AppMode::ModeSelection;
            }
        }

        // Create theme
        let theme = Theme::from_config(&config.theme);

        Ok(Self {
            state,
            config,
            theme,
            checkpoint_manager,
            checkpoint_watcher,
            terminal,
            shell_output_rx: None,
            shell_executor: None,
            feature_marker_path,
            execution_handle: None,
            is_executing: Arc::new(Mutex::new(false)),
        })
    }

    /// Find feature-marker installation path
    fn find_feature_marker_path() -> Option<PathBuf> {
        // Check common installation locations
        let home = dirs::home_dir()?;

        // Check ~/.claude/skills/feature-marker
        let claude_path = home.join(".claude/skills/feature-marker");
        if claude_path.join("feature-marker.sh").exists() {
            return Some(claude_path);
        }

        // Check if running from feature-marker repo
        if let Ok(current_dir) = std::env::current_dir() {
            let local_path = current_dir.join("feature-marker-dist/feature-marker");
            if local_path.join("feature-marker.sh").exists() {
                return Some(local_path);
            }
        }

        None
    }

    /// Run the application main loop
    pub async fn run(&mut self) -> Result<()> {
        loop {
            // Check for shell output
            self.process_shell_output();

            // Check for checkpoint changes
            self.process_checkpoint_changes();

            // Check if execution completed
            self.check_execution_status().await;

            // Render
            self.terminal.draw(|frame| {
                render_layout(frame, &self.state, &self.theme);
            })?;

            // Check for quit
            if self.state.mode == AppMode::Quitting {
                break;
            }

            // Handle events
            if event::poll(Duration::from_millis(50))? {
                if let Event::Key(key) = event::read()? {
                    if key.kind == KeyEventKind::Press {
                        self.handle_key(key.code, key.modifiers).await?;
                    }
                }
            }
        }

        Ok(())
    }

    /// Process shell output from the executor
    fn process_shell_output(&mut self) {
        if let Some(ref mut rx) = self.shell_output_rx {
            while let Ok(line) = rx.try_recv() {
                let output = if line.starts_with("$ ") {
                    OutputLine::command(&line[2..])
                } else if line.starts_with("[stderr]") {
                    OutputLine::warning(line)
                } else if line.contains("error") || line.contains("Error") || line.contains("ERROR")
                {
                    OutputLine::error(line)
                } else if line.contains("✓") || line.contains("success") || line.contains("passed")
                {
                    OutputLine::success(line)
                } else {
                    OutputLine::info(line)
                };
                self.state.add_output(output);
            }
        }
    }

    /// Process checkpoint file changes
    fn process_checkpoint_changes(&mut self) {
        if let Some(ref watcher) = self.checkpoint_watcher {
            if let Some(change) = watcher.poll_changes() {
                match change {
                    CheckpointChange::Modified(feature_name) => {
                        // Reload if it's the current feature
                        if let Some(ref current) = self.state.feature {
                            if current.feature_name == feature_name {
                                if let Ok(updated) = self.checkpoint_manager.load(&feature_name) {
                                    self.state.feature = Some(updated);
                                    self.state
                                        .add_output(OutputLine::info("Checkpoint updated"));
                                }
                            }
                        }
                    }
                    CheckpointChange::Deleted(feature_name) => {
                        if let Some(ref current) = self.state.feature {
                            if current.feature_name == feature_name {
                                self.state.add_output(OutputLine::warning(
                                    "Checkpoint deleted externally",
                                ));
                            }
                        }
                        // Refresh features list
                        self.state.available_features =
                            self.checkpoint_manager.list_features().unwrap_or_default();
                    }
                }
            }
        }
    }

    /// Check if execution task completed
    async fn check_execution_status(&mut self) {
        if let Some(ref mut handle) = self.execution_handle {
            if handle.is_finished() {
                match handle.await {
                    Ok(Ok(exit_code)) => {
                        if exit_code == 0 {
                            self.state.add_output(OutputLine::success(format!(
                                "Execution completed successfully (exit code: {})",
                                exit_code
                            )));
                            // Update phase status
                            if let Some(ref mut feature) = self.state.feature {
                                if let Some(phase) =
                                    feature.get_phase_mut(feature.current_phase)
                                {
                                    phase.complete();
                                }
                                feature.current_phase += 1;
                                if feature.current_phase > 4 {
                                    self.state.mode = AppMode::Completed;
                                }
                                let _ = self.checkpoint_manager.save(feature);
                            }
                            self.regenerate_kanban();
                        } else {
                            self.state.add_output(OutputLine::error(format!(
                                "Execution failed (exit code: {})",
                                exit_code
                            )));
                            self.state.mode =
                                AppMode::Error(format!("Exit code: {}", exit_code));
                        }
                    }
                    Ok(Err(e)) => {
                        self.state
                            .add_output(OutputLine::error(format!("Execution error: {}", e)));
                        self.state.mode = AppMode::Error(e.to_string());
                    }
                    Err(e) => {
                        self.state
                            .add_output(OutputLine::error(format!("Task error: {}", e)));
                    }
                }
                self.execution_handle = None;
                *self.is_executing.lock().await = false;
            }
        }
    }

    /// Start feature-marker execution
    async fn start_execution(&mut self) -> Result<()> {
        let Some(ref feature) = self.state.feature else {
            return Ok(());
        };
        let Some(mode) = self.state.execution_mode else {
            return Ok(());
        };

        // Create output channel
        let (tx, rx) = create_output_channel();
        self.shell_output_rx = Some(rx);

        // Create shell executor
        let executor = Arc::new(ShellExecutor::new(self.state.project_dir.clone(), tx));
        self.shell_executor = Some(executor.clone());

        // Build optional prompt file prefix
        let prompt_prefix = if let Some(ref _prompt) = self.state.feature_prompt {
            let prompt_file = self
                .checkpoint_manager
                .feature_dir(&feature.feature_name)
                .join("prompt.txt");
            format!("FEATURE_PROMPT_FILE='{}' ", prompt_file.display())
        } else {
            String::new()
        };

        // Determine command to run
        let command = if let Some(ref fm_path) = self.feature_marker_path {
            let script = fm_path.join("feature-marker.sh");
            let mode_arg = match mode {
                ExecutionMode::Full => "full",
                ExecutionMode::TasksOnly => "tasks-only",
                ExecutionMode::RalphLoop => "ralph-loop",
                ExecutionMode::SpecDriven => "spec-driven",
            };
            format!(
                "{}{} --feature {} --mode {}",
                prompt_prefix,
                script.display(),
                feature.feature_name,
                mode_arg
            )
        } else {
            // Fallback: run basic commands based on mode
            self.state.add_output(OutputLine::warning(
                "Feature-marker not found, running basic commands",
            ));
            match mode {
                ExecutionMode::Full => "echo 'Running full workflow...'".to_string(),
                ExecutionMode::TasksOnly => "echo 'Running tasks only...'".to_string(),
                ExecutionMode::RalphLoop => "echo 'Running ralph loop...'".to_string(),
                ExecutionMode::SpecDriven => "echo 'Running spec-driven...'".to_string(),
            }
        };

        // Update phase status
        if let Some(ref mut feature) = self.state.feature {
            if let Some(phase) = feature.get_phase_mut(feature.current_phase) {
                phase.status = PhaseStatus::InProgress;
                phase.started_at = Some(chrono::Utc::now());
            }
            let _ = self.checkpoint_manager.save(feature);
        }

        self.state.add_output(OutputLine::command(&command));

        // Start execution in background
        *self.is_executing.lock().await = true;
        let executor_clone = executor.clone();
        let command_clone = command.clone();

        self.execution_handle = Some(tokio::spawn(async move {
            executor_clone.execute(&command_clone).await
        }));

        Ok(())
    }

    /// Handle keyboard input
    async fn handle_key(&mut self, key: KeyCode, modifiers: KeyModifiers) -> Result<()> {
        // Global quit (skip in input modes)
        if key == KeyCode::Char('q') && !self.state.ui.input_mode
            && self.state.mode != AppMode::PromptInput
        {
            self.state.mode = AppMode::Quitting;
            return Ok(());
        }

        // Global kanban toggle (skip in text-input modes)
        if key == KeyCode::Char('K')
            && !self.state.ui.input_mode
            && self.state.mode != AppMode::PromptInput
        {
            if self.state.mode == AppMode::KanbanView {
                self.close_kanban();
            } else {
                self.open_kanban()?;
            }
            return Ok(());
        }

        match &self.state.mode.clone() {
            AppMode::Welcome => self.handle_welcome_key(key),
            AppMode::FeatureSelection => self.handle_feature_select_key(key),
            AppMode::PromptInput => self.handle_prompt_input_key(key, modifiers),
            AppMode::ModeSelection => self.handle_mode_select_key(key).await,
            AppMode::Executing => self.handle_executing_key(key),
            AppMode::Paused => self.handle_paused_key(key).await,
            AppMode::Completed => self.handle_completed_key(key),
            AppMode::Error(_) => self.handle_error_key(key),
            AppMode::KanbanView => self.handle_kanban_key(key),
            AppMode::Quitting => Ok(()),
        }
    }

    fn handle_welcome_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Enter => {
                self.state.mode = AppMode::FeatureSelection;
                self.state.ui.selected_index = 0;
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_feature_select_key(&mut self, key: KeyCode) -> Result<()> {
        if self.state.ui.input_mode {
            match key {
                KeyCode::Enter => {
                    if !self.state.ui.input_buffer.is_empty() {
                        let feature_name = self.state.ui.input_buffer.clone();
                        let is_new = !self.checkpoint_manager.exists(&feature_name);
                        self.create_or_load_feature(&feature_name)?;
                        self.state.ui.input_buffer.clear();
                        self.state.ui.input_mode = false;
                        if is_new {
                            self.state.mode = AppMode::PromptInput;
                        } else {
                            self.state.mode = AppMode::ModeSelection;
                            self.state.ui.selected_index = 0;
                        }
                    }
                }
                KeyCode::Esc => {
                    self.state.ui.input_mode = false;
                    self.state.ui.input_buffer.clear();
                }
                KeyCode::Backspace => {
                    self.state.ui.input_buffer.pop();
                }
                KeyCode::Char(c) => {
                    if c.is_alphanumeric() || c == '-' || c == '_' {
                        self.state.ui.input_buffer.push(c);
                    }
                }
                _ => {}
            }
        } else {
            match key {
                KeyCode::Char('j') | KeyCode::Down => {
                    self.state
                        .ui
                        .select_down(self.state.available_features.len());
                }
                KeyCode::Char('k') | KeyCode::Up => {
                    self.state.ui.select_up(self.state.available_features.len());
                }
                KeyCode::Char('n') => {
                    self.state.ui.input_mode = true;
                }
                KeyCode::Enter => {
                    if !self.state.available_features.is_empty() {
                        let feature_name =
                            self.state.available_features[self.state.ui.selected_index].clone();
                        // Selecting from list is always a resume
                        self.create_or_load_feature(&feature_name)?;
                        self.state.mode = AppMode::ModeSelection;
                        self.state.ui.selected_index = 0;
                    }
                }
                KeyCode::Esc => {
                    self.state.mode = AppMode::Welcome;
                }
                _ => {}
            }
        }
        Ok(())
    }

    async fn handle_mode_select_key(&mut self, key: KeyCode) -> Result<()> {
        let modes = ExecutionMode::all();

        match key {
            KeyCode::Char('j') | KeyCode::Down => {
                self.state.ui.select_down(modes.len());
            }
            KeyCode::Char('k') | KeyCode::Up => {
                self.state.ui.select_up(modes.len());
            }
            KeyCode::Char('1') => {
                self.select_mode(ExecutionMode::Full).await?;
            }
            KeyCode::Char('2') => {
                self.select_mode(ExecutionMode::TasksOnly).await?;
            }
            KeyCode::Char('3') => {
                self.select_mode(ExecutionMode::RalphLoop).await?;
            }
            KeyCode::Char('4') => {
                self.select_mode(ExecutionMode::SpecDriven).await?;
            }
            KeyCode::Enter => {
                let mode = modes[self.state.ui.selected_index];
                self.select_mode(mode).await?;
            }
            KeyCode::Esc => {
                self.state.mode = AppMode::FeatureSelection;
                self.state.ui.selected_index = 0;
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_executing_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Char('p') => {
                self.state.mode = AppMode::Paused;
                self.state.add_output(OutputLine::warning("Execution paused"));
            }
            KeyCode::Char('s') => {
                self.state.ui.toggle_auto_scroll();
            }
            KeyCode::Tab => {
                self.state.ui.focus.toggle();
            }
            KeyCode::Char('j') | KeyCode::Down => {
                self.state
                    .ui
                    .scroll_down(self.state.output_buffer.len(), 1);
            }
            KeyCode::Char('k') | KeyCode::Up => {
                self.state.ui.scroll_up(1);
            }
            KeyCode::PageDown => {
                self.state
                    .ui
                    .scroll_down(self.state.output_buffer.len(), 10);
            }
            KeyCode::PageUp => {
                self.state.ui.scroll_up(10);
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_paused_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Char('r') => {
                self.state.mode = AppMode::Executing;
                self.state.add_output(OutputLine::info("Execution resumed"));
                // Resume execution if not running
                if !*self.is_executing.lock().await {
                    self.start_execution().await?;
                }
            }
            KeyCode::Char('s') => {
                self.state.ui.toggle_auto_scroll();
            }
            KeyCode::Tab => {
                self.state.ui.focus.toggle();
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_completed_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Enter => {
                self.state.feature = None;
                self.state.execution_mode = None;
                self.state.clear_output();
                self.state.mode = AppMode::FeatureSelection;
                self.state.ui.selected_index = 0;
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_error_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Char('r') => {
                self.state.mode = AppMode::Executing;
                self.state.add_output(OutputLine::info("Retrying..."));
            }
            KeyCode::Char('s') => {
                if let Some(feature) = &mut self.state.feature {
                    if let Some(phase) = feature.get_phase_mut(feature.current_phase) {
                        phase.complete();
                    }
                    feature.current_phase += 1;
                    if feature.current_phase > 4 {
                        self.state.mode = AppMode::Completed;
                    } else {
                        self.state.mode = AppMode::Executing;
                    }
                    self.checkpoint_manager.save(feature)?;
                }
                self.regenerate_kanban();
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_prompt_input_key(&mut self, key: KeyCode, modifiers: KeyModifiers) -> Result<()> {
        match key {
            KeyCode::Enter if modifiers.contains(KeyModifiers::ALT) => {
                self.state.ui.prompt_buffer.push('\n');
            }
            KeyCode::Enter => {
                let prompt = self.state.ui.prompt_buffer.trim().to_string();
                let mut should_regenerate = false;
                if !prompt.is_empty() {
                    if let Some(ref mut feature) = self.state.feature {
                        feature.prompt = Some(prompt.clone());
                        self.checkpoint_manager
                            .write_artifact(&feature.feature_name, "prompt.txt", &prompt)?;
                        self.checkpoint_manager.save(feature)?;
                        should_regenerate = true;
                    }
                    self.state.feature_prompt = Some(prompt);
                }
                if should_regenerate {
                    self.regenerate_kanban();
                }
                self.state.ui.prompt_buffer.clear();
                self.state.mode = AppMode::ModeSelection;
                self.state.ui.selected_index = 0;
            }
            KeyCode::Esc => {
                self.state.ui.prompt_buffer.clear();
                self.state.mode = AppMode::FeatureSelection;
            }
            KeyCode::Backspace => {
                self.state.ui.prompt_buffer.pop();
            }
            KeyCode::Char(c) => {
                self.state.ui.prompt_buffer.push(c);
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_kanban_key(&mut self, key: KeyCode) -> Result<()> {
        match key {
            KeyCode::Esc => {
                self.close_kanban();
            }
            _ => {}
        }
        Ok(())
    }

    fn open_kanban(&mut self) -> Result<()> {
        self.state.kanban_features = self
            .checkpoint_manager
            .list_features()
            .unwrap_or_default()
            .iter()
            .filter_map(|f| self.checkpoint_manager.load(f).ok())
            .collect();
        self.state.previous_mode = Some(self.state.mode.clone());
        self.state.mode = AppMode::KanbanView;
        Ok(())
    }

    fn close_kanban(&mut self) {
        self.state.mode = self
            .state
            .previous_mode
            .clone()
            .unwrap_or(AppMode::FeatureSelection);
        self.state.previous_mode = None;
    }

    fn regenerate_kanban(&self) {
        let features: Vec<_> = self
            .checkpoint_manager
            .list_features()
            .unwrap_or_default()
            .iter()
            .filter_map(|f| self.checkpoint_manager.load(f).ok())
            .collect();
        let md = kanban::generate_kanban_md(&features);
        let _ = kanban::write_kanban(&self.checkpoint_manager.state_path(), &md);
    }

    fn create_or_load_feature(&mut self, feature_name: &str) -> Result<()> {
        let feature = if self.checkpoint_manager.exists(feature_name) {
            self.checkpoint_manager.load(feature_name)?
        } else {
            self.checkpoint_manager
                .init(feature_name, &self.state.project_dir)?
        };
        self.state.feature = Some(feature);
        self.state.available_features = self.checkpoint_manager.list_features().unwrap_or_default();
        Ok(())
    }

    async fn select_mode(&mut self, mode: ExecutionMode) -> Result<()> {
        self.state.execution_mode = Some(mode);
        self.state.mode = AppMode::Executing;
        self.state.ui.auto_scroll = true;
        self.state.add_output(OutputLine::info(format!(
            "Starting {} mode...",
            mode.name()
        )));

        // Start execution
        self.start_execution().await?;

        Ok(())
    }
}

impl Drop for App {
    fn drop(&mut self) {
        let _ = crossterm::terminal::disable_raw_mode();
        let _ = crossterm::execute!(
            std::io::stdout(),
            crossterm::terminal::LeaveAlternateScreen,
            crossterm::event::DisableMouseCapture
        );
    }
}

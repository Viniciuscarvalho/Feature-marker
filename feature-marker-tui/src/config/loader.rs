use anyhow::Result;
use ratatui::style::Color;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// Application configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    /// Path to task documents (default: ./tasks)
    #[serde(default = "default_docs_path")]
    pub docs_path: PathBuf,

    /// Path to state directory (default: .claude/feature-state)
    #[serde(default = "default_state_path")]
    pub state_path: PathBuf,

    /// Custom PR skill name
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pr_skill: Option<String>,

    /// Skip PR creation
    #[serde(default)]
    pub skip_pr: bool,

    /// Custom test command
    #[serde(skip_serializing_if = "Option::is_none")]
    pub test_command: Option<String>,

    /// Theme configuration
    #[serde(default)]
    pub theme: ThemeConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            docs_path: default_docs_path(),
            state_path: default_state_path(),
            pr_skill: None,
            skip_pr: false,
            test_command: None,
            theme: ThemeConfig::default(),
        }
    }
}

fn default_docs_path() -> PathBuf {
    PathBuf::from("./tasks")
}

fn default_state_path() -> PathBuf {
    PathBuf::from(".claude/feature-state")
}

/// Theme configuration for the TUI
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeConfig {
    /// Primary accent color
    #[serde(default = "default_primary")]
    pub primary: ColorDef,

    /// Success color
    #[serde(default = "default_success")]
    pub success: ColorDef,

    /// Warning color
    #[serde(default = "default_warning")]
    pub warning: ColorDef,

    /// Error color
    #[serde(default = "default_error")]
    pub error: ColorDef,

    /// Muted/secondary text color
    #[serde(default = "default_muted")]
    pub muted: ColorDef,
}

impl Default for ThemeConfig {
    fn default() -> Self {
        Self {
            primary: default_primary(),
            success: default_success(),
            warning: default_warning(),
            error: default_error(),
            muted: default_muted(),
        }
    }
}

impl ThemeConfig {
    /// Convert to ratatui Color
    pub fn primary_color(&self) -> Color {
        self.primary.to_color()
    }

    pub fn success_color(&self) -> Color {
        self.success.to_color()
    }

    pub fn warning_color(&self) -> Color {
        self.warning.to_color()
    }

    pub fn error_color(&self) -> Color {
        self.error.to_color()
    }

    pub fn muted_color(&self) -> Color {
        self.muted.to_color()
    }
}

/// Color definition that can be serialized
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ColorDef {
    Rgb { r: u8, g: u8, b: u8 },
    Named(String),
}

impl ColorDef {
    pub fn to_color(&self) -> Color {
        match self {
            ColorDef::Rgb { r, g, b } => Color::Rgb(*r, *g, *b),
            ColorDef::Named(name) => match name.to_lowercase().as_str() {
                "black" => Color::Black,
                "red" => Color::Red,
                "green" => Color::Green,
                "yellow" => Color::Yellow,
                "blue" => Color::Blue,
                "magenta" => Color::Magenta,
                "cyan" => Color::Cyan,
                "white" => Color::White,
                "gray" | "grey" => Color::Gray,
                _ => Color::White,
            },
        }
    }
}

// Default colors (matching ui.sh)
fn default_primary() -> ColorDef {
    ColorDef::Rgb {
        r: 99,
        g: 102,
        b: 241,
    } // Indigo
}

fn default_success() -> ColorDef {
    ColorDef::Rgb {
        r: 34,
        g: 197,
        b: 94,
    } // Green
}

fn default_warning() -> ColorDef {
    ColorDef::Rgb {
        r: 234,
        g: 179,
        b: 8,
    } // Yellow
}

fn default_error() -> ColorDef {
    ColorDef::Rgb {
        r: 239,
        g: 68,
        b: 68,
    } // Red
}

fn default_muted() -> ColorDef {
    ColorDef::Rgb {
        r: 107,
        g: 114,
        b: 128,
    } // Gray
}

/// Load configuration from project directory
pub fn load_config(project_dir: &Path) -> Result<AppConfig> {
    let config_path = project_dir.join(".feature-marker.json");

    if config_path.exists() {
        let content = std::fs::read_to_string(&config_path)?;
        let config: AppConfig = serde_json::from_str(&content)?;
        Ok(config)
    } else {
        Ok(AppConfig::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = AppConfig::default();
        assert_eq!(config.docs_path, PathBuf::from("./tasks"));
        assert_eq!(config.state_path, PathBuf::from(".claude/feature-state"));
        assert!(!config.skip_pr);
    }

    #[test]
    fn test_parse_config() {
        let json = r#"{
            "docs_path": "./custom/tasks",
            "skip_pr": true,
            "test_command": "npm run test:ci"
        }"#;

        let config: AppConfig = serde_json::from_str(json).unwrap();
        assert_eq!(config.docs_path, PathBuf::from("./custom/tasks"));
        assert!(config.skip_pr);
        assert_eq!(config.test_command, Some("npm run test:ci".to_string()));
    }
}

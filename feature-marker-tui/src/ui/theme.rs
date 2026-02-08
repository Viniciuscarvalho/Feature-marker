use crate::config::ThemeConfig;
use ratatui::style::{Color, Modifier, Style};

/// Theme for the TUI application
#[derive(Debug, Clone)]
pub struct Theme {
    pub primary: Color,
    pub success: Color,
    pub warning: Color,
    pub error: Color,
    pub muted: Color,
    pub background: Color,
    pub foreground: Color,
}

impl Theme {
    /// Create theme from config
    pub fn from_config(config: &ThemeConfig) -> Self {
        Self {
            primary: config.primary_color(),
            success: config.success_color(),
            warning: config.warning_color(),
            error: config.error_color(),
            muted: config.muted_color(),
            background: Color::Reset,
            foreground: Color::Reset,
        }
    }

    /// Default theme
    pub fn default_theme() -> Self {
        Self {
            primary: Color::Rgb(99, 102, 241),  // Indigo
            success: Color::Rgb(34, 197, 94),   // Green
            warning: Color::Rgb(234, 179, 8),   // Yellow
            error: Color::Rgb(239, 68, 68),     // Red
            muted: Color::Rgb(107, 114, 128),   // Gray
            background: Color::Reset,
            foreground: Color::Reset,
        }
    }

    // Style builders
    pub fn style_primary(&self) -> Style {
        Style::default().fg(self.primary)
    }

    pub fn style_success(&self) -> Style {
        Style::default().fg(self.success)
    }

    pub fn style_warning(&self) -> Style {
        Style::default().fg(self.warning)
    }

    pub fn style_error(&self) -> Style {
        Style::default().fg(self.error)
    }

    pub fn style_muted(&self) -> Style {
        Style::default().fg(self.muted)
    }

    pub fn style_bold(&self) -> Style {
        Style::default().add_modifier(Modifier::BOLD)
    }

    pub fn style_selected(&self) -> Style {
        Style::default()
            .fg(self.primary)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_header(&self) -> Style {
        Style::default()
            .fg(self.primary)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_border(&self) -> Style {
        Style::default().fg(self.muted)
    }

    pub fn style_border_focused(&self) -> Style {
        Style::default().fg(self.primary)
    }
}

impl Default for Theme {
    fn default() -> Self {
        Self::default_theme()
    }
}

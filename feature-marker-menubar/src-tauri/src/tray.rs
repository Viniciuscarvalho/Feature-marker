use crate::state::AppState;
use anyhow::Result;
use std::sync::Arc;
use tauri::{
    image::Image,
    menu::{MenuBuilder, MenuItemBuilder, SubmenuBuilder},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, PhysicalPosition,
};
use tokio::sync::Mutex;

// Store the tray icon position for window positioning
static TRAY_ICON_POSITION: std::sync::OnceLock<std::sync::Mutex<(i32, i32)>> = std::sync::OnceLock::new();

fn get_tray_position() -> Option<(i32, i32)> {
    TRAY_ICON_POSITION
        .get()
        .and_then(|pos| pos.lock().ok())
        .map(|p| *p)
        .filter(|(x, _)| *x > 0) // Only return if we have a valid position
}

fn set_tray_position(x: i32, y: i32) {
    if let Some(pos) = TRAY_ICON_POSITION.get() {
        if let Ok(mut p) = pos.lock() {
            *p = (x, y);
        }
    } else {
        let _ = TRAY_ICON_POSITION.set(std::sync::Mutex::new((x, y)));
    }
}

/// Load the tray icon from the icons directory
fn load_tray_icon() -> Image<'static> {
    // Try to load the tray icon (template icon for macOS menu bar)
    let icon_bytes: &[u8] = include_bytes!("../icons/tray-icon@2x.png");
    Image::from_bytes(icon_bytes)
        .expect("Failed to load tray icon")
        .to_owned()
}

/// Set up the system tray with menu
pub fn setup_tray(app: &tauri::App) -> Result<()> {
    let app_handle = app.handle();

    // Build the tray menu
    let menu = build_tray_menu(app_handle)?;

    // Load the tray icon (template icon for macOS menu bar)
    let tray_icon = load_tray_icon();

    // Create tray icon
    let _tray = TrayIconBuilder::with_id("main")
        .icon(tray_icon)
        .icon_as_template(true) // Makes the icon adapt to light/dark mode on macOS
        .menu(&menu)
        .tooltip("Feature-Marker")
        .on_menu_event(move |app, event| {
            handle_menu_event(app, event.id().as_ref());
        })
        .on_tray_icon_event(|tray, event| {
            match event {
                TrayIconEvent::Click {
                    button: MouseButton::Left,
                    button_state: MouseButtonState::Up,
                    position,
                    ..
                } => {
                    // Store the tray icon position for window positioning
                    set_tray_position(position.x as i32, position.y as i32);
                    let app = tray.app_handle();
                    toggle_dashboard_window(app);
                }
                // Capture position from any click for later use
                TrayIconEvent::Click { position, .. } => {
                    set_tray_position(position.x as i32, position.y as i32);
                }
                // Capture position when mouse enters tray icon area
                TrayIconEvent::Enter { position, .. } => {
                    set_tray_position(position.x as i32, position.y as i32);
                }
                _ => {}
            }
        })
        .build(app)?;

    Ok(())
}

/// Build the tray context menu
fn build_tray_menu(app: &AppHandle) -> Result<tauri::menu::Menu<tauri::Wry>> {
    // Header
    let header = MenuItemBuilder::with_id("header", "Feature-Marker v2.0.0")
        .enabled(false)
        .build(app)?;

    // Main actions
    let start_feature = MenuItemBuilder::with_id("start_feature", "Start New Feature...")
        .accelerator("Cmd+N")
        .build(app)?;

    let resume_feature = MenuItemBuilder::with_id("resume_feature", "Resume Last Feature")
        .accelerator("Cmd+R")
        .build(app)?;

    let show_dashboard = MenuItemBuilder::with_id("show_dashboard", "Show Dashboard")
        .accelerator("Cmd+D")
        .build(app)?;

    // Recent features submenu
    let recent_submenu = SubmenuBuilder::new(app, "Recent Features")
        .item(&MenuItemBuilder::with_id("no_recent", "No recent features").enabled(false).build(app)?)
        .build()?;

    // Settings
    let set_project = MenuItemBuilder::with_id("set_project", "Set Project Directory...")
        .build(app)?;

    let preferences = MenuItemBuilder::with_id("preferences", "Preferences...")
        .accelerator("Cmd+,")
        .build(app)?;

    // Quit
    let quit = MenuItemBuilder::with_id("quit", "Quit Feature-Marker")
        .accelerator("Cmd+Q")
        .build(app)?;

    let menu = MenuBuilder::new(app)
        .item(&header)
        .separator()
        .item(&start_feature)
        .item(&resume_feature)
        .separator()
        .item(&show_dashboard)
        .item(&recent_submenu)
        .separator()
        .item(&set_project)
        .item(&preferences)
        .separator()
        .item(&quit)
        .build()?;

    Ok(menu)
}

/// Handle tray menu events
fn handle_menu_event(app: &AppHandle, event_id: &str) {
    match event_id {
        "start_feature" => {
            show_dashboard_with_mode(app, "start");
        }
        "resume_feature" => {
            let app_handle = app.clone();
            tauri::async_runtime::spawn(async move {
                resume_last_feature(&app_handle).await;
            });
        }
        "show_dashboard" => {
            toggle_dashboard_window(app);
        }
        "set_project" => {
            let _ = app.emit("show-project-picker", ());
        }
        "preferences" => {
            show_dashboard_with_mode(app, "settings");
        }
        "quit" => {
            app.exit(0);
        }
        id if id.starts_with("feature_") => {
            let feature_name = id.strip_prefix("feature_").unwrap_or("");
            let _ = app.emit("select-feature", feature_name);
            show_dashboard_with_mode(app, "feature");
        }
        _ => {
            tracing::debug!("Unhandled menu event: {}", event_id);
        }
    }
}

/// Toggle dashboard window visibility
fn toggle_dashboard_window(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("dashboard") {
        if window.is_visible().unwrap_or(false) {
            let _ = window.hide();
        } else {
            position_window_near_tray(app, &window);
            let _ = window.show();
            let _ = window.set_focus();
        }
    }
}

/// Show dashboard with specific mode
fn show_dashboard_with_mode(app: &AppHandle, mode: &str) {
    let _ = app.emit("set-view-mode", mode);
    if let Some(window) = app.get_webview_window("dashboard") {
        position_window_near_tray(app, &window);
        let _ = window.show();
        let _ = window.set_focus();
    }
}

/// Position window near the system tray (below the tray icon)
fn position_window_near_tray(_app: &AppHandle, window: &tauri::WebviewWindow) {
    let window_size = window.outer_size().unwrap_or(tauri::PhysicalSize::new(400, 500));

    // Get the tray icon position, or use a default (right side of screen)
    let tray_x = if let Some((x, _)) = get_tray_position() {
        x
    } else if let Some(monitor) = window.primary_monitor().ok().flatten() {
        // Default: position on the right side of the screen (where tray icons usually are)
        monitor.size().width as i32 - 200
    } else {
        800 // Fallback
    };

    // Position the window centered below the tray icon
    // On macOS, the menu bar is at y=0, tray icons are around y=11
    // We position the window just below the menu bar (around y=25)
    let window_x = tray_x - (window_size.width as i32 / 2);
    let window_y = 25; // Just below the macOS menu bar

    // Ensure window stays on screen
    let final_x = if let Some(monitor) = window.primary_monitor().ok().flatten() {
        let monitor_width = monitor.size().width as i32;
        // Ensure window doesn't go off right edge
        let max_x = monitor_width - window_size.width as i32 - 10;
        // Ensure window doesn't go off left edge
        window_x.max(10).min(max_x)
    } else {
        window_x.max(10)
    };

    let _ = window.set_position(PhysicalPosition::new(final_x, window_y));
}

/// Resume the last active feature
async fn resume_last_feature(app: &AppHandle) {
    let state = app.state::<Arc<Mutex<AppState>>>();
    let mut state_guard = state.lock().await;

    match state_guard.list_features() {
        Ok(features) => {
            if let Some(last_feature) = features.first() {
                let feature_name = last_feature.name.clone();
                drop(state_guard);
                let _ = app.emit("resume-feature", &feature_name);
                show_dashboard_with_mode(app, "feature");
            } else {
                drop(state_guard);
                // No features found, show the list view (which displays empty state)
                show_dashboard_with_mode(app, "list");
            }
        }
        Err(e) => {
            tracing::error!("Failed to list features: {}", e);
            drop(state_guard);
            // Show list view on error
            show_dashboard_with_mode(app, "list");
        }
    }
}

/// Update the tray menu with current features
pub async fn update_tray_menu(app: &AppHandle, features: Vec<crate::state::FeatureSummary>) -> Result<()> {
    // For now, emit an event to update the menu from the frontend
    // Full dynamic menu updates in Tauri v2 require recreating the menu
    let _ = app.emit("features-updated", features);
    Ok(())
}

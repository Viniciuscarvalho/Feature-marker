#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod process_manager;
mod state;
mod tray;

use state::AppState;
use std::sync::Arc;
use tauri::Manager;
use tokio::sync::Mutex;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() {
    // Initialize logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "feature_marker_menubar=debug".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Starting Feature-Marker Menu Bar App");

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            // Initialize shared state
            let state = Arc::new(Mutex::new(AppState::new()?));
            app.manage(state.clone());

            // Set up system tray
            tray::setup_tray(app)?;

            // Start file watcher for checkpoint changes
            let app_handle = app.handle().clone();
            let state_clone = state.clone();
            tauri::async_runtime::spawn(async move {
                if let Err(e) = state::watch_checkpoints(app_handle, state_clone).await {
                    tracing::error!("Checkpoint watcher error: {}", e);
                }
            });

            tracing::info!("Feature-Marker Menu Bar initialized successfully");
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_features,
            commands::get_feature_state,
            commands::start_feature,
            commands::resume_feature,
            commands::pause_feature,
            commands::cancel_feature,
            commands::get_output_log,
            commands::open_project_dir,
            commands::get_app_config,
            commands::set_project_dir,
            commands::open_terminal,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

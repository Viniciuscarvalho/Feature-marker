mod app;

use anyhow::Result;
use clap::Parser;
use feature_marker_tui::config;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "feature-marker-tui")]
#[command(author = "Vinicius Carvalho")]
#[command(version = "0.1.0")]
#[command(about = "Terminal User Interface for Feature-Marker workflow automation")]
struct Args {
    /// Feature name to work with
    #[arg(short, long)]
    feature: Option<String>,

    /// Project directory (defaults to current directory)
    #[arg(short, long)]
    project: Option<PathBuf>,

    /// Skip to specific execution mode
    #[arg(short, long, value_parser = ["full", "tasks-only", "ralph-loop", "spec-driven"])]
    mode: Option<String>,

    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Initialize logging if debug mode
    if args.debug {
        tracing_subscriber::fmt()
            .with_env_filter("feature_marker_tui=debug")
            .init();
    }

    // Determine project directory
    let project_dir = args.project.unwrap_or_else(|| {
        std::env::current_dir().expect("Failed to get current directory")
    });

    // Load configuration
    let config = config::load_config(&project_dir)?;

    // Create and run the application
    let mut app = app::App::new(config, project_dir, args.feature, args.mode)?;
    app.run().await
}

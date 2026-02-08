# Feature-Marker TUI

Terminal User Interface for Feature-Marker workflow automation.

## Prerequisites

### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, restart your terminal or run:
```bash
source ~/.cargo/env
```

## Building

```bash
cd feature-marker-tui
cargo build --release
```

The binary will be at `target/release/feature-marker-tui`.

## Running

```bash
# From project directory
./target/release/feature-marker-tui

# With options
./target/release/feature-marker-tui --feature my-feature --mode full
```

## Usage

### Keyboard Shortcuts

| Key | Action | Context |
|-----|--------|---------|
| `j` / `↓` | Navigate down | Menu/List |
| `k` / `↑` | Navigate up | Menu/List |
| `Enter` | Select | Menu |
| `q` | Quit | Global |
| `Esc` | Back | Any |
| `p` | Pause execution | During execution |
| `r` | Resume | Paused |
| `s` | Toggle auto-scroll | Output |
| `Tab` | Switch focus | Between panes |

### Screens

1. **Welcome** - Banner and start prompt
2. **Feature Selection** - Create new or resume existing feature
3. **Mode Selection** - Choose execution mode (Full, Tasks-Only, Ralph Loop, Spec-Driven)
4. **Dashboard** - Real-time execution monitoring with phase progress and output stream

## Configuration

The TUI reads configuration from `.feature-marker.json` in your project directory:

```json
{
  "docs_path": "./tasks",
  "state_path": ".claude/feature-state",
  "skip_pr": false,
  "test_command": "npm test"
}
```

## Development

```bash
# Run with debug logging
cargo run -- --debug

# Run tests
cargo test

# Format code
cargo fmt

# Check for issues
cargo clippy
```

## Architecture

```
src/
├── main.rs           # Entry point
├── app.rs            # Application loop
├── model/            # State management
├── ui/               # Rendering
│   ├── screens/      # Full-screen views
│   └── widgets/      # Reusable components
├── integration/      # External integrations
└── config/           # Configuration loading
```

## License

MIT

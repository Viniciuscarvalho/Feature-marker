# Feature-Marker Menu Bar v4.0.0

A native macOS menu bar application for Feature-Marker workflow automation.

## Installation

### Quick Install

```bash
./scripts/install.sh
```

This builds and installs the app to `/Applications/Feature-Marker.app`.

### Development

```bash
./scripts/dev.sh
```

## Usage

1. **Click the tray icon** to open the dashboard
2. **Set project directory** via Settings (Cmd+,)
3. **Start a feature** with name, mode, and optional requirements
4. **Monitor progress** in real-time with output streaming

### Workflow Modes

| Mode | Description |
|------|-------------|
| **Full** | Generate missing docs + execute all phases |
| **Tasks Only** | Use existing docs, skip generation |
| **Ralph Loop** | Autonomous execution with self-correction |
| **Spec Driven** | Generate from requirements, skip PRD |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | Start New Feature |
| Cmd+R | Resume Last Feature |
| Cmd+D | Show Dashboard |
| Cmd+, | Settings |
| Cmd+Q | Quit |
| ESC | Close Window |

## Requirements

- **macOS** 11+ (Big Sur or later)
- **Rust** 1.70+ via [rustup.rs](https://rustup.rs)
- **Node.js** 18+ via [nodejs.org](https://nodejs.org)
- **Xcode Command Line Tools**: `xcode-select --install`

## Architecture

```
feature-marker-menubar/
├── ui/                     # Frontend (Vite + TypeScript)
│   └── src/main.ts        # Main application logic
├── src-tauri/              # Backend (Rust + Tauri v2)
│   └── src/
│       ├── main.rs        # Entry point
│       ├── tray.rs        # System tray
│       ├── commands.rs    # Tauri IPC commands
│       ├── state.rs       # State management
│       └── process_manager.rs # Process execution
└── scripts/
    ├── dev.sh             # Development runner
    └── install.sh         # Build & install
```

## Related

- [feature-marker-dist](../feature-marker-dist/) - CLI tool (v1.6.0)
- [feature-marker-tui](../feature-marker-tui/) - Terminal UI (v3.0.0)

## License

MIT

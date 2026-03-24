# Feature-Marker Menu Bar v5.3.0

A native macOS menu bar application for Feature-Marker workflow automation, built with Swift/SwiftUI.

## Requirements

- **macOS 15+** (Sequoia)
- **Xcode Command Line Tools**: `xcode-select --install`

## Build & Install

```bash
# Build release .app bundle
./build.sh

# Run
open dist/Feature-Marker.app
```

To install permanently, copy `dist/Feature-Marker.app` to `/Applications/`.

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
| **Spec Driven** | Multi-agent review with worktree isolation |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | Start New Feature |
| Cmd+R | Resume Last Feature |
| Cmd+D | Show Dashboard |
| Cmd+, | Settings |
| Cmd+Q | Quit |

## Architecture

```
feature-marker-menubar/
├── Package.swift                     # SPM manifest (zero dependencies)
├── build.sh                          # Release build script
└── Sources/FeatureMarkerMenuBar/
    ├── App/                          # Entry point + AppDelegate
    ├── Models/                       # Codable models (checkpoint.json)
    ├── State/                        # @Observable state management
    ├── Services/                     # ProcessManager, FileWatcher, Notifications
    ├── MenuBar/                      # NSStatusItem + NSPopover + NSMenu
    └── Views/                        # SwiftUI views + components
```

**Key design decisions:**
- Zero external dependencies (Foundation, AppKit, SwiftUI, UserNotifications)
- `@Observable` + `@MainActor` for efficient property-level state tracking
- Actor-based `ProcessManager` and `FileWatcher` for safe concurrency
- NSStatusItem + NSPopover for native menu bar UX with vibrancy material
- Binary size: ~839 KB (release, `-Osize`)

## Related

- [feature-marker-dist](../feature-marker-dist/) - CLI tool
- [feature-marker-tui](../feature-marker-tui/) - Terminal UI

## License

MIT

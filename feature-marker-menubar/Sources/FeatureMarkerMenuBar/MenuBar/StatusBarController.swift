import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static weak var shared: StatusBarController?

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private nonisolated(unsafe) var eventMonitor: Any?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()
        Self.shared = self

        setupStatusButton()
        setupPopover()
        setupEventMonitor()
    }

    // MARK: - Setup

    private func setupStatusButton() {
        guard let button = statusItem.button else { return }

        // Use SF Symbol as template icon (adapts to light/dark mode)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "Feature-Marker")
        button.image = image?.withSymbolConfiguration(config)

        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(appState: appState)
        )
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click works next time
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Header
        let header = NSMenuItem(title: "Feature-Marker v2.0.0", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Start
        let start = NSMenuItem(
            title: "Start New Feature...",
            action: #selector(menuStartFeature),
            keyEquivalent: "n"
        )
        start.keyEquivalentModifierMask = .command
        start.target = self
        menu.addItem(start)

        // Resume
        let resume = NSMenuItem(
            title: "Resume Last Feature",
            action: #selector(menuResumeFeature),
            keyEquivalent: "r"
        )
        resume.keyEquivalentModifierMask = .command
        resume.target = self
        menu.addItem(resume)

        menu.addItem(.separator())

        // Dashboard
        let dashboard = NSMenuItem(
            title: "Show Dashboard",
            action: #selector(menuShowDashboard),
            keyEquivalent: "d"
        )
        dashboard.keyEquivalentModifierMask = .command
        dashboard.target = self
        menu.addItem(dashboard)

        // Recent Features submenu
        let recentSubmenu = NSMenu(title: "Recent Features")
        if appState.features.isEmpty {
            let empty = NSMenuItem(title: "No recent features", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentSubmenu.addItem(empty)
        } else {
            for feature in appState.features.prefix(5) {
                let item = NSMenuItem(
                    title: feature.name,
                    action: #selector(menuSelectFeature(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = feature.name
                recentSubmenu.addItem(item)
            }
        }
        let recentItem = NSMenuItem(title: "Recent Features", action: nil, keyEquivalent: "")
        recentItem.submenu = recentSubmenu
        menu.addItem(recentItem)

        menu.addItem(.separator())

        // Set Project
        let setProject = NSMenuItem(
            title: "Set Project Directory...",
            action: #selector(menuSetProject),
            keyEquivalent: ""
        )
        setProject.target = self
        menu.addItem(setProject)

        // Preferences
        let prefs = NSMenuItem(
            title: "Preferences...",
            action: #selector(menuShowPreferences),
            keyEquivalent: ","
        )
        prefs.keyEquivalentModifierMask = .command
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(
            title: "Quit Feature-Marker",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = .command
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Menu Actions

    @objc private func menuStartFeature() {
        appState.currentView = .start
        showPopover()
    }

    @objc private func menuResumeFeature() {
        if let first = appState.features.first {
            appState.selectedFeature = first.name
            appState.currentView = .detail
            showPopover()
            Task {
                try? await appState.resumeFeature(name: first.name)
            }
        } else {
            appState.currentView = .list
            showPopover()
        }
    }

    @objc private func menuShowDashboard() {
        appState.currentView = .list
        showPopover()
    }

    @objc private func menuSelectFeature(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        appState.selectedFeature = name
        appState.currentView = .detail
        showPopover()
    }

    @objc private func menuSetProject() {
        pickProjectDirectory()
    }

    @objc private func menuShowPreferences() {
        appState.currentView = .settings
        showPopover()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - Project Picker

    func pickProjectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Project Directory"

        if panel.runModal() == .OK, let url = panel.url {
            appState.setProjectDirectory(url)
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

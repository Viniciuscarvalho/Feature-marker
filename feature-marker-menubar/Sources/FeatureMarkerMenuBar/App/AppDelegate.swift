import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(appState: appState)

        Task {
            await appState.startFileWatching()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.terminateRunningProcess()
    }
}

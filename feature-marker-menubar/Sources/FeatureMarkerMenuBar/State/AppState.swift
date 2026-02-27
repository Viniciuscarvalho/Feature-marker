import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    // MARK: - Configuration

    var projectDir: URL?
    var featureMarkerPath: URL

    // MARK: - UI State

    var currentView: ViewMode = .list
    var selectedFeature: String?

    // MARK: - Feature Data

    var features: [FeatureSummary] = []
    var runningFeature: RunningFeature?
    var outputLog: [OutputLine] = []

    // MARK: - Services

    private let processManager = ProcessManager()
    private let fileWatcher = FileWatcher()

    // MARK: - Constants

    private static let maxOutputLines = 1000

    enum ViewMode: Sendable {
        case list, start, detail, settings
    }

    // MARK: - Init

    init() {
        self.featureMarkerPath = PathResolver.findFeatureMarkerPath()

        if let cwd = FileManager.default.currentDirectoryPath as String? {
            self.projectDir = URL(fileURLWithPath: cwd)
        }
    }

    // MARK: - Feature Loading

    func loadFeatures() {
        guard let projectDir else {
            features = []
            return
        }

        let stateDir = PathResolver.stateDirectory(for: projectDir)
        let fm = FileManager.default

        guard fm.fileExists(atPath: stateDir.path(percentEncoded: false)) else {
            features = []
            return
        }

        guard let entries = try? fm.contentsOfDirectory(
            at: stateDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            features = []
            return
        }

        var summaries: [FeatureSummary] = []

        for entry in entries where entry.hasDirectoryPath {
            let checkpoint = entry.appending(path: "checkpoint.json")
            guard fm.fileExists(atPath: checkpoint.path(percentEncoded: false)),
                  let state = loadFeatureState(at: checkpoint) else { continue }

            let name = entry.lastPathComponent
            summaries.append(FeatureSummary(
                name: name,
                currentPhase: state.currentPhase,
                totalPhases: PhaseInfo.count,
                phaseStatus: state.phaseStatus,
                lastUpdated: state.lastUpdated,
                isRunning: runningFeature?.name == name,
                paused: state.paused,
                hasError: state.errorState != nil
            ))
        }

        summaries.sort { $0.lastUpdated > $1.lastUpdated }
        features = summaries
    }

    func loadFeatureState(name: String) -> FeatureState? {
        guard let projectDir else { return nil }
        let path = PathResolver.stateDirectory(for: projectDir)
            .appending(path: name)
            .appending(path: "checkpoint.json")
        return loadFeatureState(at: path)
    }

    private func loadFeatureState(at path: URL) -> FeatureState? {
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder.checkpoint.decode(FeatureState.self, from: data)
    }

    // MARK: - Feature Execution

    func startFeature(name: String, mode: String) async throws {
        guard let projectDir else {
            throw AppError.noProjectDir
        }

        guard FileManager.default.fileExists(atPath: projectDir.path(percentEncoded: false)) else {
            throw AppError.projectDirNotFound(projectDir.path(percentEncoded: false))
        }

        runningFeature = RunningFeature(name: name, mode: mode, startedAt: Date())
        outputLog.removeAll()

        addOutput("Starting feature: \(name)", isStderr: false)
        addOutput("Mode: \(mode)", isStderr: false)
        addOutput("Project: \(projectDir.path(percentEncoded: false))", isStderr: false)
        addOutput("", isStderr: false)

        do {
            let pid = try await processManager.spawn(
                projectDir: projectDir,
                feature: name,
                mode: mode,
                onOutput: { [weak self] line, isStderr in
                    self?.addOutput(line, isStderr: isStderr)
                },
                onComplete: { [weak self] success in
                    guard let self else { return }
                    let featureName = self.runningFeature?.name ?? name
                    if success {
                        self.addOutput("Feature '\(featureName)' completed successfully", isStderr: false)
                    } else {
                        self.addOutput("Feature '\(featureName)' exited with error", isStderr: true)
                    }
                    self.runningFeature = nil
                    self.loadFeatures()
                }
            )

            runningFeature?.processID = pid
            addOutput("Process started (PID: \(pid))", isStderr: false)
            selectedFeature = name
            currentView = .detail
        } catch {
            runningFeature = nil
            throw error
        }
    }

    func cancelFeature() async {
        guard runningFeature != nil else { return }
        addOutput("Cancelling feature...", isStderr: false)
        await processManager.cancel()
    }

    func resumeFeature(name: String) async throws {
        try await startFeature(name: name, mode: "full")
    }

    // MARK: - File Watching

    func startFileWatching() async {
        guard let projectDir else { return }
        let stateDir = PathResolver.stateDirectory(for: projectDir)

        // Initial load
        loadFeatures()

        // Request notification permission
        await NotificationService.requestPermission()

        // Start watching
        await fileWatcher.watch(directory: stateDir) { [weak self] featureName in
            guard let self else { return }
            self.loadFeatures()
            self.checkPhaseCompletion(feature: featureName)
        }
    }

    private func checkPhaseCompletion(feature: String) {
        guard let state = loadFeatureState(name: feature) else { return }

        for (key, phase) in state.phases {
            guard phase.status == .completed,
                  let completedAt = phase.completedAt,
                  let index = Int(key) else { continue }

            let elapsed = Date().timeIntervalSince(completedAt)
            if elapsed >= 0 && elapsed < 5 {
                NotificationService.sendPhaseCompletion(
                    feature: state.featureName,
                    phaseName: phase.name,
                    phaseIndex: index
                )
            }
        }
    }

    // MARK: - Output

    private func addOutput(_ text: String, isStderr: Bool) {
        outputLog.append(OutputLine(text: text, isStderr: isStderr))
        if outputLog.count > Self.maxOutputLines {
            outputLog.removeFirst()
        }
    }

    // MARK: - Process Cleanup

    nonisolated func terminateRunningProcess() {
        Task {
            await processManager.forceKill()
        }
    }

    // MARK: - Helpers

    func openProjectInFinder() {
        guard let projectDir else { return }
        NSWorkspace.shared.open(projectDir)
    }

    func openTerminalAtProject() {
        guard let projectDir else { return }
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(projectDir.path(percentEncoded: false))'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func setProjectDirectory(_ url: URL) {
        projectDir = url
        loadFeatures()

        Task {
            await startFileWatching()
        }
    }

    enum AppError: Error, LocalizedError {
        case noProjectDir
        case projectDirNotFound(String)

        var errorDescription: String? {
            switch self {
            case .noProjectDir:
                "No project directory set. Please set one in Settings."
            case .projectDirNotFound(let path):
                "Project directory not found: \(path)"
            }
        }
    }
}

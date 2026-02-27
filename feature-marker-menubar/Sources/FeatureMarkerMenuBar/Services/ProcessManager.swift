import Foundation

actor ProcessManager {
    private var currentProcess: Process?

    var isRunning: Bool {
        currentProcess?.isRunning ?? false
    }

    var processID: Int32? {
        currentProcess?.processIdentifier
    }

    func spawn(
        projectDir: URL,
        feature: String,
        mode: String,
        onOutput: @MainActor @Sendable @escaping (String, Bool) -> Void,
        onComplete: @MainActor @Sendable @escaping (Bool) -> Void
    ) throws -> Int32 {
        guard currentProcess == nil else {
            throw ProcessError.alreadyRunning
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            """
            source $HOME/.cargo/env 2>/dev/null; \
            cd '\(projectDir.path(percentEncoded: false))' && \
            claude --dangerously-skip-permissions '/feature-marker --mode \(mode) \(feature)'
            """
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Task { @MainActor in
                for line in lines {
                    onOutput(line, false)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Task { @MainActor in
                for line in lines {
                    onOutput("[stderr] \(line)", true)
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor in
                onComplete(proc.terminationStatus == 0)
            }
            Task {
                await self?.clearProcess()
            }
        }

        try process.run()
        self.currentProcess = process
        return process.processIdentifier
    }

    func cancel() {
        guard let process = currentProcess, process.isRunning else { return }
        process.terminate() // SIGTERM

        let pid = process.processIdentifier
        Task {
            try? await Task.sleep(for: .seconds(3))
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    func forceKill() {
        guard let process = currentProcess else { return }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        currentProcess = nil
    }

    private func clearProcess() {
        currentProcess = nil
    }

    enum ProcessError: Error, LocalizedError {
        case alreadyRunning

        var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                "A feature is already running. Please wait or cancel it first."
            }
        }
    }
}

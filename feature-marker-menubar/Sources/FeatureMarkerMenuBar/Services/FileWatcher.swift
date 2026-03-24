import Foundation

actor FileWatcher {
    private var source: (any DispatchSourceFileSystemObject)?
    private var directoryHandle: Int32 = -1
    private var lastKnownDates: [String: Date] = [:]
    private var watchTask: Task<Void, Never>?

    func watch(
        directory: URL,
        onChange: @MainActor @Sendable @escaping (String) -> Void
    ) {
        stop()

        let path = directory.path(percentEncoded: false)
        directoryHandle = open(path, O_EVTONLY)
        guard directoryHandle != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryHandle,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.scanForChanges(in: directory, onChange: onChange) }
        }

        source.setCancelHandler { [fd = directoryHandle] in
            close(fd)
        }

        source.resume()
        self.source = source

        // Periodic poll as backup for nested file changes
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await self?.scanForChanges(in: directory, onChange: onChange)
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
        source?.cancel()
        source = nil
        directoryHandle = -1
    }

    private func scanForChanges(
        in directory: URL,
        onChange: @MainActor @Sendable @escaping (String) -> Void
    ) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for entry in entries where entry.hasDirectoryPath {
            let checkpoint = entry.appending(path: "checkpoint.json")
            guard fm.fileExists(atPath: checkpoint.path(percentEncoded: false)) else { continue }

            guard let attrs = try? fm.attributesOfItem(atPath: checkpoint.path(percentEncoded: false)),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            let featureName = entry.lastPathComponent

            if let lastDate = lastKnownDates[featureName] {
                if modDate > lastDate {
                    Task { @MainActor in onChange(featureName) }
                }
            }
            lastKnownDates[featureName] = modDate
        }
    }
}

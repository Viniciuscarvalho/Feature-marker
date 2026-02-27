import Foundation

enum PathResolver {
    static func findFeatureMarkerPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appending(path: ".feature-marker"),
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?.appending(path: "feature-marker"),
            Bundle.main.executableURL?.deletingLastPathComponent()
        ].compactMap { $0 }

        for candidate in candidates {
            let script = candidate.appending(path: "feature-marker.sh")
            if FileManager.default.fileExists(atPath: script.path(percentEncoded: false)) {
                return candidate
            }
        }

        return home.appending(path: ".feature-marker")
    }

    static func stateDirectory(for projectDir: URL) -> URL {
        projectDir.appending(path: ".claude/feature-state")
    }
}

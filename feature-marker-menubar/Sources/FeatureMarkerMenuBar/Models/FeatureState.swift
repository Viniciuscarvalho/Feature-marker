import Foundation

// MARK: - Phase Status

enum PhaseStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case error
}

// MARK: - Phase

struct Phase: Codable, Sendable {
    let name: String
    let status: PhaseStatus
    var startedAt: Date?
    var completedAt: Date?
    var currentTaskIndex: Int?
    var totalTasks: Int?
    var completedTasks: [Int] = []
    var outputs: [String] = []

    enum CodingKeys: String, CodingKey {
        case name, status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case currentTaskIndex = "current_task_index"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case outputs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(PhaseStatus.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        currentTaskIndex = try container.decodeIfPresent(Int.self, forKey: .currentTaskIndex)
        totalTasks = try container.decodeIfPresent(Int.self, forKey: .totalTasks)
        completedTasks = (try? container.decode([Int].self, forKey: .completedTasks)) ?? []
        outputs = (try? container.decode([String].self, forKey: .outputs)) ?? []
    }
}

// MARK: - Feature State (checkpoint.json)

struct FeatureState: Codable, Sendable {
    let version: String
    let featureName: String
    let projectPath: String
    let currentPhase: Int
    let phaseStatus: PhaseStatus
    let phases: [String: Phase]
    let lastUpdated: Date
    var paused: Bool
    var errorState: String?

    enum CodingKeys: String, CodingKey {
        case version
        case featureName = "feature_name"
        case projectPath = "project_path"
        case currentPhase = "current_phase"
        case phaseStatus = "phase_status"
        case phases
        case lastUpdated = "last_updated"
        case paused
        case errorState = "error_state"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        featureName = try container.decode(String.self, forKey: .featureName)
        projectPath = try container.decode(String.self, forKey: .projectPath)
        currentPhase = try container.decode(Int.self, forKey: .currentPhase)
        phaseStatus = try container.decode(PhaseStatus.self, forKey: .phaseStatus)
        phases = try container.decode([String: Phase].self, forKey: .phases)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        paused = (try? container.decode(Bool.self, forKey: .paused)) ?? false
        errorState = try container.decodeIfPresent(String.self, forKey: .errorState)
    }
}

// MARK: - Feature Summary (for list display)

struct FeatureSummary: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let currentPhase: Int
    let totalPhases: Int
    let phaseStatus: PhaseStatus
    let lastUpdated: Date
    let isRunning: Bool
    let paused: Bool
    let hasError: Bool

    var progress: Double {
        Double(currentPhase) / Double(totalPhases)
    }
}

// MARK: - Running Feature

struct RunningFeature: Sendable {
    let name: String
    let mode: String
    let startedAt: Date
    var processID: Int32?
}

// MARK: - Output Line

struct OutputLine: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let isStderr: Bool
    let timestamp = Date()

    var isSuccess: Bool {
        text.contains("\u{2713}") || text.contains("\u{2705}")
    }
}

// MARK: - JSON Decoder

extension JSONDecoder {
    static var checkpoint: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // ISO 8601 with fractional seconds (microseconds)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback: without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}

// MARK: - Phase Names

enum PhaseInfo {
    static let names = [
        "Inputs Gate",
        "Analysis & Planning",
        "Implementation",
        "Tests & Validation",
        "Commit & PR"
    ]
    static let count = 5
}

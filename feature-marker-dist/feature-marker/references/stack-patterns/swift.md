# Swift Stack Patterns

Conventions and patterns for Swift/iOS projects. Loaded when `platform-context.json` reports `primary_platform=ios`.

## Architecture

### MVVM + Clean Architecture (recommended)

```
Sources/
├── Domain/
│   ├── Entities/          # Pure data models
│   ├── UseCases/          # Business logic protocols + implementations
│   └── Repositories/      # Repository protocols (abstractions)
├── Data/
│   ├── Repositories/      # Repository implementations
│   ├── Services/          # Network/DB services
│   └── DTOs/              # Data Transfer Objects
└── Presentation/
    └── Features/
        └── {Feature}/
            ├── {Feature}View.swift
            ├── {Feature}ViewModel.swift
            └── Components/   # Feature-specific UI components
```

### Key Principles

- ViewModels are `@Observable` classes (Swift 5.9+) or `ObservableObject` with `@Published`
- UseCases are protocols with a single `execute()` method
- Repositories abstract data sources behind protocols
- Views never access repositories directly — always through ViewModel → UseCase → Repository

## Swift Testing Patterns

### Test Structure

```swift
import Testing
@testable import {ModuleName}

@Suite("{ComponentName} Tests")
struct {ComponentName}Tests {
    @Test("describes expected behavior")
    func behaviorDescription() async throws {
        // Arrange
        // Act
        // Assert with #expect()
    }
}
```

### Assertions

| Pattern                                            | Usage          |
| -------------------------------------------------- | -------------- |
| `#expect(value == expected)`                       | Equality check |
| `#expect(value != nil)`                            | Non-nil check  |
| `#expect(throws: SomeError.self) { try action() }` | Error throwing |
| `#require(optionalValue)`                          | Unwrap or fail |

### Mocking

- Create mock implementations of protocols in test targets
- Use constructor injection for all dependencies
- Name mocks as `Mock{ProtocolName}`

## Error Handling

```swift
// Define domain errors as enums
enum FeatureError: Error, LocalizedError {
    case notFound(id: String)
    case unauthorized
    case networkFailure(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id): "Resource not found: \(id)"
        case .unauthorized: "Not authorized"
        case .networkFailure(let e): "Network error: \(e.localizedDescription)"
        }
    }
}
```

## File Naming

| Type       | Convention                      | Example                              |
| ---------- | ------------------------------- | ------------------------------------ |
| View       | `{Feature}View.swift`           | `TrainerProfileView.swift`           |
| ViewModel  | `{Feature}ViewModel.swift`      | `TrainerProfileViewModel.swift`      |
| UseCase    | `{Action}{Entity}UseCase.swift` | `FetchTrainerUseCase.swift`          |
| Repository | `{Entity}Repository.swift`      | `TrainerRepository.swift`            |
| Service    | `{Domain}Service.swift`         | `AuthenticationService.swift`        |
| Test       | `{OriginalName}Tests.swift`     | `TrainerProfileViewModelTests.swift` |

## Concurrency

- Use `async/await` for all asynchronous operations
- Use `Task { }` for launching async work from synchronous contexts
- Use `@MainActor` for ViewModel classes that update UI state
- Avoid `DispatchQueue` unless interfacing with legacy APIs

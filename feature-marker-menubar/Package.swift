// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureMarkerMenuBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "FeatureMarkerMenuBar",
            path: "Sources/FeatureMarkerMenuBar",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

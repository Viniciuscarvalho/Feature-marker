// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SampleApp",
    products: [
        .executable(name: "SampleApp", targets: ["App"]),
        .library(name: "SampleLib", targets: ["SampleLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["SampleLib"],
            path: "Sources/App"
        ),
        .target(
            name: "SampleLib",
            path: "Sources/SampleLib"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["SampleLib"],
            path: "Tests/AppTests"
        ),
    ]
)

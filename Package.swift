// swift-tools-version:6.0
import PackageDescription

// Run tests with scripts/test.sh, not bare `swift test`: with only the Command Line
// Tools installed, SwiftPM can't locate the Swift Testing framework (see experience.md).
let package = Package(
    name: "Falah",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Falah",
            path: "Sources/Falah"
        ),
        .testTarget(
            name: "FalahTests",
            dependencies: ["Falah"],
            path: "Tests/FalahTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

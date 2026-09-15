// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VibeFlow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VibeFlowCore", targets: ["VibeFlowCore"]),
        .executable(name: "VibeFlow", targets: ["VibeFlowApp"]),
        .executable(name: "vibeflow-smoke", targets: ["VibeFlowSmoke"]),
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            path: ".vendor/whisper.xcframework"
        ),
        .target(
            name: "VibeFlowCore",
            dependencies: ["whisper"],
            path: "Sources/VibeFlowCore",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .executableTarget(
            name: "VibeFlowApp",
            dependencies: ["VibeFlowCore"],
            path: "Sources/VibeFlowApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "VibeFlowSmoke",
            dependencies: ["VibeFlowCore"],
            path: "Sources/VibeFlowSmoke"
        ),
        .testTarget(
            name: "VibeFlowCoreTests",
            dependencies: ["VibeFlowCore"],
            path: "Tests/VibeFlowCoreTests"
        ),
    ]
)

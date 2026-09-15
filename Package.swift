// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HormeFlow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HormeFlowCore", targets: ["HormeFlowCore"]),
        .executable(name: "HormeFlow", targets: ["HormeFlowApp"]),
        .executable(name: "horme-flow-smoke", targets: ["HormeFlowSmoke"]),
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            path: ".vendor/whisper.xcframework"
        ),
        .target(
            name: "HormeFlowCore",
            dependencies: ["whisper"],
            path: "Sources/HormeFlowCore",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .executableTarget(
            name: "HormeFlowApp",
            dependencies: ["HormeFlowCore"],
            path: "Sources/HormeFlowApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "HormeFlowSmoke",
            dependencies: ["HormeFlowCore"],
            path: "Sources/HormeFlowSmoke"
        ),
        .testTarget(
            name: "HormeFlowCoreTests",
            dependencies: ["HormeFlowCore"],
            path: "Tests/HormeFlowCoreTests"
        ),
    ]
)

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PitchKiwi",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PitchKiwiCore", targets: ["PitchKiwiCore"]),
        .executable(name: "PitchKiwi", targets: ["PitchKiwiApp"]),
        .executable(name: "pitchkiwi-smoke", targets: ["PitchKiwiSmoke"]),
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            path: ".vendor/whisper.xcframework"
        ),
        .target(
            name: "PitchKiwiCore",
            dependencies: ["whisper"],
            path: "Sources/PitchKiwiCore",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .executableTarget(
            name: "PitchKiwiApp",
            dependencies: ["PitchKiwiCore"],
            path: "Sources/PitchKiwiApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "PitchKiwiSmoke",
            dependencies: ["PitchKiwiCore"],
            path: "Sources/PitchKiwiSmoke"
        ),
        .testTarget(
            name: "PitchKiwiCoreTests",
            dependencies: ["PitchKiwiCore"],
            path: "Tests/PitchKiwiCoreTests"
        ),
    ]
)

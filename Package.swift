// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NeonDrift",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NeonDrift",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameUI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "GameUI",
            targets: ["GameUI"]
        ),
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameApp")
    ],
    targets: [
        .target(
            name: "GameUI",
            dependencies: ["GameCore", "GameApp"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GameUITests",
            dependencies: ["GameUI"]
        ),
    ]
)

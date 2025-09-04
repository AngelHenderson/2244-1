// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameUI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GameUI",
            targets: ["GameUI"]
        ),
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameApp"),
        .package(path: "../GameServices")
    ],
    targets: [
        .target(
            name: "GameUI",
            dependencies: ["GameCore", "GameApp", "GameServices"],
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
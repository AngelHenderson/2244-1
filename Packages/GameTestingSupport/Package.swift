// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameTestingSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GameTestingSupport",
            targets: ["GameTestingSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameApp"),
        .package(path: "../GameServices")
    ],
    targets: [
        .target(
            name: "GameTestingSupport",
            dependencies: ["GameCore", "GameApp", "GameServices"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
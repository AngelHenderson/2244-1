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
        .package(path: "../GameApp"),
        .package(path: "../GameServices")
    ],
    targets: [
        .target(
            name: "GameUI",
            dependencies: ["GameCore", "GameApp", "GameServices"],
            exclude: [
                "Leaderboard/check_missing_brackets.py",
                "Leaderboard/check_missing_countries.py",
                "Leaderboard/check_missing_names.py",
                "Leaderboard/generate_cases.py"
            ],
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

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "GameCore",
            targets: ["GameCore"]
        ),
    ],
    targets: [
        .target(
            name: "GameCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
    ]
)
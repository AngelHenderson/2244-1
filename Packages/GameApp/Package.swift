// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameApp",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "GameApp",
            targets: ["GameApp"]
        ),
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameServices")
    ],
    targets: [
        .target(
            name: "GameApp",
            dependencies: ["GameCore", "GameServices"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GameAppTests",
            dependencies: [
                "GameApp",
                .product(name: "GameServices", package: "GameServices")
            ]
        ),
    ]
)
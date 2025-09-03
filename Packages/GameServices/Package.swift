// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameServices",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GameServices",
            targets: ["GameServices"]
        ),
    ],
    targets: [
        .target(
            name: "GameServices",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GameServicesTests",
            dependencies: ["GameServices"]
        ),
    ]
)
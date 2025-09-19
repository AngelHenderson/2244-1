// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GlassPreview",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "GlassPreview",
            targets: ["GlassPreview"]
        ),
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameServices"),
        .package(path: "../GameTestingSupport")
    ],
    targets: [
        .target(
            name: "GlassPreview",
            dependencies: [
                "GameCore",
                "GameServices"
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
            ]
        ),
        .testTarget(
            name: "GlassPreviewTests",
            dependencies: [
                "GlassPreview",
                "GameTestingSupport"
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
            ]
        ),
    ]
)

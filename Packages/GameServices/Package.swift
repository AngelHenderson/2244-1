// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameServices",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "GameServices",
            targets: ["GameServices"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.2.0"),
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "GameServices",
            dependencies: [
                "GameCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GameServicesTests",
            dependencies: ["GameServices", "GameCore"]
        ),
    ]
)
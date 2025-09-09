// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameServices",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GameServices",
            targets: ["GameServices"]
        ),
    ],
    dependencies: [
        // Firebase dependency - uncomment when ready to deploy
        // .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
    ],
    targets: [
        .target(
            name: "GameServices",
            dependencies: [
                // Firebase dependencies - uncomment when ready to deploy
                // .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                // .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                // .product(name: "FirebaseFunctions", package: "firebase-ios-sdk")
            ],
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
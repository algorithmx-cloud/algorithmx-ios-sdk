// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlgorithmXSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AlgorithmXSDK",
            targets: ["AlgorithmXSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AlgorithmXSDK",
            dependencies: [],
            path: "Sources/AlgorithmXSDK",
            // Apple privacy manifest: collected data and UserDefaults reasons.
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ]
)

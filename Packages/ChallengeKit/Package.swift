// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChallengeKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ChallengeKit", targets: ["ChallengeKit"])
    ],
    dependencies: [
        .package(path: "../AlarmCore")
    ],
    targets: [
        .target(name: "ChallengeKit", dependencies: ["AlarmCore"]),
        .testTarget(name: "ChallengeKitTests", dependencies: ["ChallengeKit"])
    ]
)

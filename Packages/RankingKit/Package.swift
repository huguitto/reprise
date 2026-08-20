// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RankingKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "RankingKit", targets: ["RankingKit"])
    ],
    dependencies: [
        .package(path: "../AlarmCore")
    ],
    targets: [
        .target(name: "RankingKit", dependencies: ["AlarmCore"]),
        .testTarget(name: "RankingKitTests", dependencies: ["RankingKit"])
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AlarmScheduler",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AlarmScheduler", targets: ["AlarmScheduler"])
    ],
    dependencies: [
        .package(path: "../AlarmCore")
    ],
    targets: [
        .target(name: "AlarmScheduler", dependencies: ["AlarmCore"]),
        .testTarget(name: "AlarmSchedulerTests", dependencies: ["AlarmScheduler"])
    ]
)

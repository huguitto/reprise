// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"])
    ],
    dependencies: [
        .package(path: "../AlarmCore")
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["AlarmCore"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"])
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(path: "../AlarmCore")
    ],
    targets: [
        .target(name: "DesignSystem", dependencies: ["AlarmCore"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"])
    ]
)

// swift-tools-version: 6.2
import PackageDescription

// AlarmCore es dominio puro: sin SwiftUI, sin CoreMotion, sin AlarmKit, sin red.
// Declara macOS ademas de iOS a proposito, para que `swift test` corra en el host
// y en CI sin necesidad de simulador. Si alguna vez necesitas importar un framework
// solo-iOS aqui, es senal de que ese codigo no pertenece a este paquete.
let package = Package(
    name: "AlarmCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AlarmCore", targets: ["AlarmCore"])
    ],
    targets: [
        .target(name: "AlarmCore"),
        .testTarget(name: "AlarmCoreTests", dependencies: ["AlarmCore"])
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(path: "../AlarmCore"),
        // Por los textos del permiso (`AlarmAuthorizationCopy`) y los mensajes
        // de `AlarmSchedulerError`, que son texto de usuario y acaban en
        // pantalla. Nada de aqui importa AlarmKit: el paquete entero compila en
        // el host detras de `#if canImport`.
        .package(path: "../AlarmScheduler")
    ],
    targets: [
        .target(name: "DesignSystem", dependencies: ["AlarmCore", "AlarmScheduler"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"])
    ]
)

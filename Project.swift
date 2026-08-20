import ProjectDescription

let bundleID = "com.hrocha.reprise"

let project = Project(
    name: "RepRise",
    organizationName: "RepRise",
    packages: [
        .local(path: "Packages/AlarmCore"),
        .local(path: "Packages/AlarmScheduler"),
        .local(path: "Packages/ChallengeKit"),
        .local(path: "Packages/Persistence"),
        .local(path: "Packages/RankingKit"),
        .local(path: "Packages/DesignSystem")
    ],
    settings: .settings(
        base: ["SWIFT_VERSION": "6.0", "SWIFT_STRICT_CONCURRENCY": "complete"]
    ),
    targets: [
        .target(
            name: "RepRise",
            destinations: .iOS,
            product: .app,
            bundleId: bundleID,
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "RepRise",
                "UILaunchScreen": ["UIColorName": ""],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                // AlarmKit: obligatorio, y el texto lo lee el usuario en el
                // dialogo de permiso. Tambien lo lee quien revisa en Apple.
                "NSAlarmKitUsageDescription": "RepRise necesita programar alarmas para despertarte y que no puedas apagarlas sin moverte.",
                "NSMotionUsageDescription": "RepRise cuenta tus pasos y tus sentadillas para saber que te has levantado de verdad.",
                "CFBundleLocalizations": ["es"],
                "CFBundleDevelopmentRegion": "es"
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .package(product: "AlarmCore"),
                .package(product: "AlarmScheduler"),
                .package(product: "ChallengeKit"),
                .package(product: "Persistence"),
                .package(product: "RankingKit"),
                .package(product: "DesignSystem")
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BearMinderCore",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "BearMinderCore", targets: [
            "Models", "BeeminderClient", "BearClient", "Persistence", "SyncManager", "KeychainSupport", "Logging", "Config"
        ]),
        .executable(name: "bearminder-cli", targets: ["bearminder-cli"])
    ],
    targets: [
        .target(name: "Models", dependencies: []),
        .target(name: "Logging", dependencies: []),
        .target(name: "KeychainSupport", dependencies: ["Logging"]),
        .target(name: "BeeminderClient", dependencies: ["Models", "Logging", "KeychainSupport"]),
        .target(name: "BearClient", dependencies: ["Models", "Logging", "KeychainSupport"]),
        .target(name: "Persistence", dependencies: ["Models", "Logging"]),
        .target(name: "SyncManager", dependencies: ["Models", "BeeminderClient", "BearClient", "Persistence", "Logging"]),
        .target(name: "Config", dependencies: ["Logging"]),
        .executableTarget(name: "bearminder-cli", dependencies: [
            "Models", "BeeminderClient", "BearClient", "Persistence", "SyncManager", "Logging", "Config"
        ]),
        .testTarget(name: "BearMinderCoreTests", dependencies: [
            "Models", "BeeminderClient", "BearClient", "Persistence", "SyncManager", "KeychainSupport", "Logging"
        ])
    ]
)

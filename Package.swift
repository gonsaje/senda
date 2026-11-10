// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Senda",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SendaDomain", targets: ["SendaDomain"]),
        .library(name: "SendaPersistence", targets: ["SendaPersistence"]),
        .library(name: "SendaLogger", targets: ["SendaLogger"]),
        .library(name: "SendaNotebook", targets: ["SendaNotebook"]),
        .executable(name: "senda-sample", targets: ["SendaSample"]),
        .executable(name: "senda-preview", targets: ["SendaPreview"])
    ],
    targets: [
        .target(name: "SendaDomain"),
        .target(name: "SendaPersistence", dependencies: ["SendaDomain"]),
        .target(name: "SendaLogger", dependencies: ["SendaDomain", "SendaPersistence"]),
        .target(name: "SendaNotebook", dependencies: ["SendaDomain", "SendaLogger", "SendaPersistence"],
                resources: [.process("Resources")]),
        .executableTarget(name: "SendaSample", dependencies: ["SendaDomain"]),
        .executableTarget(name: "SendaPreview", dependencies: ["SendaNotebook", "SendaDomain", "SendaLogger", "SendaPersistence"]),
        .testTarget(name: "SendaDomainTests", dependencies: ["SendaDomain"]),
        .testTarget(name: "SendaPersistenceTests", dependencies: ["SendaPersistence"]),
        .testTarget(name: "SendaLoggerTests", dependencies: ["SendaLogger"]),
        .testTarget(name: "SendaNotebookTests", dependencies: ["SendaNotebook"])
    ]
)

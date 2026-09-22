// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JevDesktop",
    platforms: [.macOS("14.2")],
    products: [.library(name: "JevCore", targets: ["JevCore"]), .executable(name: "JevDesktop", targets: ["JevDesktop"]),
               .executable(name: "jev-realtime", targets: ["JevRealtimeCLI"])],
    targets: [
        .target(name: "JevCore"),
        .executableTarget(name: "JevDesktop", dependencies: ["JevCore"]),
        .executableTarget(name: "JevRealtimeCLI", dependencies: ["JevCore"]),
        .testTarget(name: "JevCoreTests", dependencies: ["JevCore"])
    ]
)

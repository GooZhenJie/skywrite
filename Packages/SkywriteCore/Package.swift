// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SkywriteCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "SkywriteCore", targets: ["SkywriteCore"]),
    ],
    targets: [
        .target(name: "SkywriteCore"),
        .testTarget(name: "SkywriteCoreTests", dependencies: ["SkywriteCore"]),
    ]
)

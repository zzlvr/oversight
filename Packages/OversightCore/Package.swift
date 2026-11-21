// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OversightCore",
    platforms: [.iOS("18.0"), .macOS("14.0")],
    products: [
        .library(name: "OversightCore", targets: ["OversightCore"])
    ],
    targets: [
        .target(name: "OversightCore"),
        .testTarget(name: "OversightCoreTests", dependencies: ["OversightCore"])
    ]
)

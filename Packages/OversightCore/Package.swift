// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OversightCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "OversightCore", targets: ["OversightCore"])
    ],
    targets: [
        .target(name: "OversightCore"),
        .testTarget(name: "OversightCoreTests", dependencies: ["OversightCore"])
    ]
)

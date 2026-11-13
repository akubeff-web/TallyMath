// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MathCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "MathCore", targets: ["MathCore"]),
    ],
    targets: [
        .target(name: "MathCore"),
        .testTarget(name: "MathCoreTests", dependencies: ["MathCore"]),
    ]
)

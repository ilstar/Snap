// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snap",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Snap", targets: ["Snap"])],
    targets: [
        .target(name: "SnapCore"),
        .executableTarget(name: "Snap", dependencies: ["SnapCore"]),
        .testTarget(name: "SnapCoreTests", dependencies: ["SnapCore"])
    ]
)

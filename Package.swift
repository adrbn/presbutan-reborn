// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PresButanReborn",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PresButanReborn",
            path: "Sources/PresButanReborn"
        ),
        .testTarget(
            name: "PresButanRebornTests",
            dependencies: ["PresButanReborn"],
            path: "Tests/PresButanRebornTests"
        ),
    ]
)

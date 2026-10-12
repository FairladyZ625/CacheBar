// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CacheBar",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "CacheBar",
            dependencies: ["CacheBarCore"]
        ),
        .target(
            name: "CacheBarCore"
        ),
        .testTarget(
            name: "CacheBarTests",
            dependencies: ["CacheBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

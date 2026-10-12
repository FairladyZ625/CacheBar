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
            dependencies: ["CacheBarUI"]
        ),
        // 仅开发用：普通窗口 + 假数据渲染同一份面板，供截图；不进 build-app.sh 的产物。
        .executableTarget(
            name: "CacheBarPreview",
            dependencies: ["CacheBarUI"]
        ),
        .target(
            name: "CacheBarUI",
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

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MonoTab",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "MonoTab",
            targets: ["MonoTab"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MonoTab",
            dependencies: [],
            path: "Sources/MonoTab"
        ),
        .testTarget(
            name: "MonoTabTests",
            dependencies: ["MonoTab"],
            path: "Tests/MonoTabTests"
        )
    ]
)

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
            path: "Sources/MonoTab",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault")
            ]
        ),
        .testTarget(
            name: "MonoTabTests",
            dependencies: ["MonoTab"],
            path: "Tests/MonoTabTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)

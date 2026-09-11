// swift-tools-version: 6.2
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
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility")
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

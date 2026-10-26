// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrackerKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TrackerKit", targets: ["TrackerKit"])
    ],
    targets: [
        .target(name: "TrackerKit"),
        .testTarget(
            name: "TrackerKitTests",
            dependencies: ["TrackerKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)

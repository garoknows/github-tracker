// swift-tools-version: 6.0
// Renders docs/thesis/THESIS.pdf and docs/thesis/DECK.pdf from SwiftUI.
// Run from the repo root: swift run --package-path tools/docgen docgen .
import PackageDescription

let package = Package(
    name: "docgen",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "docgen")]
)

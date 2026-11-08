// swift-tools-version: 6.0
// Renders the printable install guide (docs/ and site/Tracker-for-GitHub-Install-Guide.pdf) from docs/INSTALL.md.
// Run from the repo root: swift run --package-path tools/docgen docgen .
import PackageDescription

let package = Package(
    name: "docgen",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "docgen")]
)

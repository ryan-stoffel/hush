// swift-tools-version: 5.10
import PackageDescription

// Dependency policy: the package ships with as few third-party dependencies as possible.
// Every entry in `dependencies` must carry a comment that says what it is for and why the
// standard SDK cannot do the job. Adding one needs an approved issue first (see AGENTS.md).
let package = Package(
    name: "Quoth",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuothCore", targets: ["QuothCore"]),
        .library(name: "QuothKit", targets: ["QuothKit"]),
    ],
    dependencies: [],
    targets: [
        // Pure logic. Foundation only, so it stays fast to build and trivial to unit test.
        .target(name: "QuothCore"),
        // Platform layer: AppKit, SwiftUI, AVFoundation, Accessibility.
        .target(name: "QuothKit", dependencies: ["QuothCore"]),
        .testTarget(name: "QuothCoreTests", dependencies: ["QuothCore"]),
        .testTarget(name: "QuothKitTests", dependencies: ["QuothKit"]),
    ]
)

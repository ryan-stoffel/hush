// swift-tools-version: 5.10
import PackageDescription

// Dependency policy: the package ships with as few third-party dependencies as possible.
// Every entry in `dependencies` must carry a comment that says what it is for and why the
// standard SDK cannot do the job. Adding one needs an approved issue first (see AGENTS.md).
let package = Package(
    name: "Hush",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HushCore", targets: ["HushCore"]),
        .library(name: "HushKit", targets: ["HushKit"]),
    ],
    dependencies: [
        // WhisperKit (pre-approved): on-device Whisper inference on Core ML and the Neural Engine,
        // including model download and tokenization. It is what makes local-by-default possible.
        // The SDK has no equivalent: SFSpeechRecognizer cannot guarantee on-device processing for
        // every language and offers no model choice. The repository was renamed from
        // argmaxinc/WhisperKit to argmax-oss-swift in 2026. 1.1.0 is the first release without the
        // empty-result bug when prompt tokens are set, which the dictionary feature relies on.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.1.0"),
    ],
    targets: [
        // Pure logic. Foundation only, so it stays fast to build and trivial to unit test.
        .target(name: "HushCore"),
        // Platform layer: AppKit, SwiftUI, AVFoundation, Accessibility, WhisperKit.
        .target(
            name: "HushKit",
            dependencies: [
                "HushCore",
                .product(
                    name: "WhisperKit",
                    package: "argmax-oss-swift",
                    condition: .when(platforms: [.macOS])
                ),
            ]
        ),
        .testTarget(name: "HushCoreTests", dependencies: ["HushCore"]),
        .testTarget(
            name: "HushKitTests",
            dependencies: ["HushKit"],
            resources: [.copy("Resources/sample-speech.wav")]
        ),
    ]
)

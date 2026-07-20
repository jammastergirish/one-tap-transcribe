// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OneTapTranscribe",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        // Local OpenAI Whisper via Core ML, tuned for Apple Silicon.
        // NOTE: WhisperKit "graduated" into the argmax-oss-swift package at
        // v1.0.0. `from: "1.0.0"` is required — `from: "0.9.0"` resolves to the
        // pre-1.0 API and won't match the calls below.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OneTapTranscribe",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/OneTapTranscribe",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

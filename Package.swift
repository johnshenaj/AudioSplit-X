// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AudioSplitX", platforms: [.macOS(.v15)], targets: [
.target(name: "AudioCore", swiftSettings: [.swiftLanguageMode(.v5)]),
.executableTarget(name: "AudioSplitX", dependencies: ["AudioCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
.testTarget(name: "AudioCoreTests", dependencies: ["AudioCore"], swiftSettings: [.swiftLanguageMode(.v5)])])

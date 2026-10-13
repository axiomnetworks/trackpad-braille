// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackpadBraille",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TrackpadBraille", path: "Sources/TrackpadBraille")
    ]
)

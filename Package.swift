// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shiyin",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Shiyin", targets: ["Shiyin"])],
    targets: [
        .executableTarget(
            name: "Shiyin",
            path: "Sources/Shiyin",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

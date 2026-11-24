// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchCopy",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NotchCopy", targets: ["NotchCopy"])],
    targets: [
        .executableTarget(name: "NotchCopy", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NotchCopyTests", dependencies: ["NotchCopy"],
                    swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)

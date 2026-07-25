// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexHomeBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexHomeBridge", targets: ["CodexHomeBridge"])
    ],
    targets: [
        .target(
            name: "CodexHomeBridgeCore"
        ),
        .executableTarget(
            name: "CodexHomeBridge",
            dependencies: ["CodexHomeBridgeCore"]
        ),
        .testTarget(
            name: "CodexHomeBridgeCoreTests",
            dependencies: ["CodexHomeBridgeCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)

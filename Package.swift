// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SetItUp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SetItUp", targets: ["SetItUp"])
    ],
    targets: [
        .target(
            name: "SetItUpCore"
        ),
        .executableTarget(
            name: "SetItUp",
            dependencies: ["SetItUpCore"]
        ),
        .testTarget(
            name: "SetItUpCoreTests",
            dependencies: ["SetItUpCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)

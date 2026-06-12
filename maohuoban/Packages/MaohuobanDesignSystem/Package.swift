// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MaohuobanDesignSystem",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        .library(
            name: "MaohuobanDesignSystem",
            targets: ["MaohuobanDesignSystem"]
        )
    ],
    targets: [
        .target(
            name: "MaohuobanDesignSystem"
        ),
        .testTarget(
            name: "MaohuobanDesignSystemTests",
            dependencies: ["MaohuobanDesignSystem"]
        )
    ]
)

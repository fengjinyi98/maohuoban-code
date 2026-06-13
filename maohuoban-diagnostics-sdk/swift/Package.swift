// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MaohuobanDiagnostics",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        .library(
            name: "MaohuobanDiagnostics",
            targets: ["MaohuobanDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "MaohuobanDiagnostics",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MaohuobanDiagnosticsTests",
            dependencies: ["MaohuobanDiagnostics"]
        ),
    ]
)

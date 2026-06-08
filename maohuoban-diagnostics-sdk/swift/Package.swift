// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MaohuobanDiagnostics",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
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

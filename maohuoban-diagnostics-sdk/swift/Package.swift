// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MaohuobanDiagnostics",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MaohuobanDiagnostics",
            targets: ["MaohuobanDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "MaohuobanDiagnostics"
        ),
        .testTarget(
            name: "MaohuobanDiagnosticsTests",
            dependencies: ["MaohuobanDiagnostics"]
        ),
    ]
)

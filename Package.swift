// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SKOrigami",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SK Origami", targets: ["SKOrigami"])
    ],
    targets: [
        .executableTarget(
            name: "SKOrigami",
            resources: [
                .process("../../Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "SKOrigamiTests",
            dependencies: ["SKOrigami"]
        )
    ]
)

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modeler",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/plate.git", from: "1.0.2"),
    ],
    targets: [
        .executableTarget(
            name: "Modeler",
            dependencies: [
                .product(name: "plate", package: "plate"),
            ]
        ),
    ]
)

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var platforms: [SupportedPlatform] = [
    .macOS(.v14),
    .iOS(.v17),
    .tvOS(.v16),
    .watchOS(.v8),
    .visionOS(.v2)
]

let package = Package(
    name: "DomainLayer",
    platforms: platforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DomainLayer",
            targets: ["DomainLayer"]),
        .library(name: "DomainProtocols",
                 targets: ["DomainProtocols"])
    ],
    dependencies: [
        .package(url: "https://github.com/Matejkob/swift-spyable", .upToNextMajor(from: "0.8.0")),
        .package(name: "Models", path: "../Models"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "DomainLayer",
                dependencies: [
                    "DomainProtocols",
                    .product(name: "Spyable", package: "swift-spyable"),
                ]),
        .target(name: "DomainProtocols",
                dependencies: [
                    .product(name: "Models", package: "Models"),
                ]),
        .testTarget(
            name: "DomainLayerTests",
            dependencies: ["DomainLayer"]
        ),
    ]
)

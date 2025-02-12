// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var platforms: [SupportedPlatform] = [
    .macOS(.v14),
    .iOS(.v18),
    .tvOS(.v16),
    .watchOS(.v8),
    .visionOS(.v2)
]

let package = Package(
    name: "PresentationLayer",
    defaultLocalization: "en",
    platforms: platforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PresentationLayer",
            targets: ["PresentationLayer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/lukacs-m/DocScanner", branch: "main"),
        .package(url: "https://github.com/hmlongco/Factory", exact: "2.4.3"),
        .package(name: "Models", path: "../Models"),
        .package(name: "DataLayer", path: "../DataLayer"),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PresentationLayer",
            dependencies: [
                .product(name: "DocScanner", package: "DocScanner"),
                .product(name: "Factory", package: "Factory"),
                .product(name: "Models", package: "Models"),
                .product(name: "DataLayer", package: "DataLayer")
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "PresentationLayerTests",
            dependencies: ["PresentationLayer"]
        ),
    ]
)

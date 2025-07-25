// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var platforms: [SupportedPlatform] = [
    .macOS(.v14),
    .iOS(.v17),
    .tvOS(.v16),
    .watchOS(.v10),
    .visionOS(.v2)
]

let package = Package(
    name: "CommonUtilities",
    platforms: platforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CommonUtilities",
            targets: ["CommonUtilities"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Models", path: "../Models"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CommonUtilities",
            dependencies: [
                .product(name: "Models", package: "Models"),
            ]
        ),
        .testTarget(
            name: "CommonUtilitiesTests",
            dependencies: ["CommonUtilities"]
        ),
    ]
)

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
    name: "DataLayer",
    defaultLocalization: "en",
    platforms: platforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DataLayer",
            targets: ["DataLayer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Models", path: "../Models"),
        .package(name: "CommonUtilities", path: "../CommonUtilities"),
        .package(name: "AuthenticatorRustCore", path: "../AuthenticatorRustCore"),
        .package(url: "https://github.com/lukacs-m/SimplyPersist", .upToNextMajor(from: "0.1.1")),
        .package(name: "Macro", path: "../Macro"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DataLayer",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "CommonUtilities", package: "CommonUtilities"),
                .product(name: "AuthenticatorRustCore", package: "AuthenticatorRustCore"),
                .product(name: "SimplyPersist", package: "SimplyPersist"),
                .product(name: "Macro", package: "Macro"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer"]
        ),
    ]
)

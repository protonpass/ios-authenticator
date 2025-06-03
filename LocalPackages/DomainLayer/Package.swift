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
            targets: ["DomainLayer"])
    ],
    dependencies: [
        .package(name: "CommonUtilities", path: "../CommonUtilities"),
        .package(name: "Models", path: "../Models"),
        .package(name: "DataLayer", path: "../DataLayer"),
        .package(name: "AuthenticatorRustCore", path: "../AuthenticatorRustCore"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", exact: "8.52.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "DomainLayer",
                dependencies: [
                    "DataLayer",
                    "AuthenticatorRustCore",
                    .product(name: "Sentry", package: "sentry-cocoa"),
                    .product(name: "CommonUtilities", package: "CommonUtilities")
                ]),
        .testTarget(
            name: "DomainLayerTests",
            dependencies: ["DomainLayer"]
        ),
    ]
)

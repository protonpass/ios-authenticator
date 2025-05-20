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
        .package(url: "https://github.com/hmlongco/Factory", exact: "2.5.1"),
        .package(url: "https://github.com/lukacs-m/SimpleToast", .upToNextMajor(from: "0.1.4")),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", .upToNextMajor(from: "3.0.0")),
        .package(name: "Models", path: "../Models"),
        .package(name: "DataLayer", path: "../DataLayer"),
        .package(name: "DomainLayer", path: "../DomainLayer"),
        .package(name: "Macro", path: "../Macro"),
        .package(name: "CommonUtilities", path: "../CommonUtilities"),
        .package(url: "https://github.com/ProtonMail/protoncore_ios", exact: "32.0.5")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PresentationLayer",
            dependencies: [
                .product(name: "DocScanner", package: "DocScanner", condition: .when(platforms: [.iOS])),
                .product(name: "Factory", package: "Factory"),
                .product(name: "Models", package: "Models"),
                .product(name: "DataLayer", package: "DataLayer"),
                .product(name: "DomainLayer", package: "DomainLayer"),
                .product(name: "Macro", package: "Macro"),
                .product(name: "CommonUtilities", package: "CommonUtilities"),
                .product(name: "SimpleToast", package: "SimpleToast"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
                .product(name: "ProtonCoreLogin", package: "protoncore_ios"),
                .product(name: "ProtonCoreLoginUI", package: "protoncore_ios"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "PresentationLayerTests",
            dependencies: ["PresentationLayer"]
        ),
    ]
)

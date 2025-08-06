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
        .package(url: "https://github.com/lukacs-m/SimplyPersist", exact: "0.1.3"),
        .package(url: "https://github.com/lukacs-m/SimpleToast", .upToNextMajor(from: "0.1.4")),
        .package(url: "https://github.com/ProtonMail/protoncore_ios", exact: "32.8.1"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "4.2.2"),
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
                .product(name: "SimpleToast", package: "SimpleToast"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),

                // Core products
                .product(name: "ProtonCoreKeyManager", package: "protoncore_ios"),
                .product(name: "ProtonCoreDoh", package: "protoncore_ios"),
                .product(name: "ProtonCoreFoundations", package: "protoncore_ios"),
                .product(name: "ProtonCoreDataModel", package: "protoncore_ios"),
                .product(name: "ProtonCoreNetworking", package: "protoncore_ios"),
                .product(name: "ProtonCoreChallenge", package: "protoncore_ios"),
                .product(name: "ProtonCoreForceUpgrade", package: "protoncore_ios"),
                .product(name: "ProtonCoreCryptoGoImplementation", package: "protoncore_ios"),
                .product(name: "ProtonCoreHumanVerification", package: "protoncore_ios"),
                .product(name: "ProtonCoreLogin", package: "protoncore_ios"),
                .product(name: "ProtonCoreKeymaker", package: "protoncore_ios"),
                .product(name: "ProtonCoreCrypto", package: "protoncore_ios"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer"]
        ),
    ]
)


// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ANModelKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ANModelKit",
            targets: ["ANModelKit"]
        ),
    ], dependencies: [
        .package(url: "https://github.com/mergesort/Boutique", exact: "3.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ANModelKit",
            dependencies: ["Boutique"]
        ),
        .testTarget(
            name: "ANModelKitTests",
            dependencies: ["ANModelKit"]
        ),
    ]
)

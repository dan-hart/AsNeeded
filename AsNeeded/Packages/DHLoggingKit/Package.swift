// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "DHLoggingKit",
	platforms: [
		.iOS(.v14),
		.macOS(.v11),
		.watchOS(.v7),
		.tvOS(.v14),
		.visionOS(.v1)
	],
	products: [
		.library(
			name: "DHLoggingKit",
			targets: ["DHLoggingKit"]
		),
	],
	dependencies: [
		// No external dependencies - uses only Apple frameworks
	],
	targets: [
		.target(
			name: "DHLoggingKit",
			dependencies: [],
			path: "Sources/DHLoggingKit"
		),
		.testTarget(
			name: "DHLoggingKitTests",
			dependencies: ["DHLoggingKit"],
			path: "Tests/DHLoggingKitTests"
		),
	],
	swiftLanguageModes: [.v6]
)
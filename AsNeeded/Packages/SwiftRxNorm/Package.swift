// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftRxNorm",
	platforms: [
		.iOS(.v15),
		.macOS(.v12),
		.watchOS(.v8),
		.tvOS(.v15),
		.visionOS(.v1)
	],
	products: [
		.library(
			name: "SwiftRxNorm",
			targets: ["SwiftRxNorm"]
		)
	],
	targets: [
		.target(
			name: "SwiftRxNorm",
			dependencies: [],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "SwiftRxNormTests",
			dependencies: ["SwiftRxNorm"],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		)
	]
)


import Foundation

/// Manages Swift Package dependencies by parsing Package.resolved and enriching with license information
final class PackageDependencyManager: Sendable {
	static let shared = PackageDependencyManager()

	private init() {}

	/// Returns all package dependencies used in the app
	func getAllDependencies() -> [PackageDependency] {
		// Hardcoded dependencies based on Package.resolved
		// This ensures dependencies are always available at runtime without file system access
		return [
			PackageDependency(
				id: "anmodelkit",
				name: "ANModelKit",
				description: "Domain models and business logic for medication tracking",
				repositoryURL: URL(string: "https://github.com/dan-hart/ANModelKit")!,
				versionInfo: .branch("main"),
				commitHash: "02380bee063a136dd6ed7fce7cee047b4f8d4d6e",
				license: .gpl3,
				isDirect: true
			),
			PackageDependency(
				id: "bodega",
				name: "Bodega",
				description: "Simple file-based storage for caching and persistence",
				repositoryURL: URL(string: "https://github.com/mergesort/Bodega")!,
				versionInfo: .version("2.1.3"),
				commitHash: "bfd8871e9c2590d31b200e54c75428a71483afdf",
				license: .mit,
				isDirect: false
			),
			PackageDependency(
				id: "boutique",
				name: "Boutique",
				description: "Simple data store for persisting medications and events",
				repositoryURL: URL(string: "https://github.com/mergesort/Boutique")!,
				versionInfo: .version("3.0.1"),
				commitHash: "9379e6a0b13bfb01c2ae655b65962d8479b63428",
				license: .mit,
				isDirect: true
			),
			PackageDependency(
				id: "dhflatuicolors",
				name: "DHFlatUIColors",
				description: "Flat UI color palette for medication customization",
				repositoryURL: URL(string: "https://github.com/dan-hart/DHFlatUIColors")!,
				versionInfo: .branch("main"),
				commitHash: "821b077fc94ba45422ded8f38ee5b532dbabfd3e",
				license: .gpl3,
				isDirect: true
			),
			PackageDependency(
				id: "dhloggingkit",
				name: "DHLoggingKit",
				description: "Unified logging infrastructure for debugging and monitoring",
				repositoryURL: URL(string: "https://github.com/dan-hart/DHLoggingKit")!,
				versionInfo: .version("1.0.0"),
				commitHash: "b75135996d38c93eda5d635949389006fc2e45ed",
				license: .gpl3,
				isDirect: true
			),
			PackageDependency(
				id: "dhutilitykit",
				name: "DHUtilityKit",
				description: "Utility functions and extensions",
				repositoryURL: URL(string: "https://github.com/dan-hart/DHUtilityKit")!,
				versionInfo: .version("1.0.4"),
				commitHash: "d2e2c03d509ace79ffdec913626099fe57d9933e",
				license: .gpl3,
				isDirect: true
			),
			PackageDependency(
				id: "purchases-ios",
				name: "RevenueCat",
				description: "In-app purchase and subscription management",
				repositoryURL: URL(string: "https://github.com/RevenueCat/purchases-ios")!,
				versionInfo: .version("5.37.0"),
				commitHash: "7abf1505551da3d8c33d4306a80c1e1cc450e47e",
				license: .mit,
				isDirect: true
			),
			PackageDependency(
				id: "sfsafesymbols",
				name: "SFSafeSymbols",
				description: "Type-safe access to SF Symbols icons",
				repositoryURL: URL(string: "https://github.com/SFSafeSymbols/SFSafeSymbols")!,
				versionInfo: .version("6.2.0"),
				commitHash: "3dd282d3269b061853a3b3bcd23a509d2aa166ce",
				license: .mit,
				isDirect: true
			),
			PackageDependency(
				id: "sqlite.swift",
				name: "SQLite.swift",
				description: "Type-safe SQLite database interface",
				repositoryURL: URL(string: "https://github.com/stephencelis/SQLite.swift")!,
				versionInfo: .version("0.15.4"),
				commitHash: "392dd6058624d9f6c5b4c769d165ddd8c7293394",
				license: .mit,
				isDirect: false
			),
			PackageDependency(
				id: "swift-collections",
				name: "Swift Collections",
				description: "Advanced collection types from Apple",
				repositoryURL: URL(string: "https://github.com/apple/swift-collections")!,
				versionInfo: .version("1.3.0"),
				commitHash: "7b847a3b7008b2dc2f47ca3110d8c782fb2e5c7e",
				license: .apache2,
				isDirect: false
			),
			PackageDependency(
				id: "swift-toolchain-sqlite",
				name: "Swift Toolchain SQLite",
				description: "Low-level SQLite bindings for Swift",
				repositoryURL: URL(string: "https://github.com/swiftlang/swift-toolchain-sqlite")!,
				versionInfo: .version("1.0.4"),
				commitHash: "b626d3002773b1a1304166643e7f118f724b2132",
				license: .apache2,
				isDirect: false
			),
			PackageDependency(
				id: "swiftrxnorm",
				name: "SwiftRxNorm",
				description: "RxNorm API client for medication name lookup",
				repositoryURL: URL(string: "https://github.com/dan-hart/SwiftRxNorm")!,
				versionInfo: .version("1.0.0"),
				commitHash: "a2cbccbdb82d2bdeb71c41db4e7497b2efaeae34",
				license: .gpl3,
				isDirect: true
			)
		].sorted { $0.name < $1.name }
	}

	/// Returns only direct dependencies (excluding transitive ones)
	func getDirectDependencies() -> [PackageDependency] {
		getAllDependencies().filter { $0.isDirect }
	}

	/// Returns only transitive dependencies
	func getTransitiveDependencies() -> [PackageDependency] {
		getAllDependencies().filter { !$0.isDirect }
	}

}

// SecretManager.swift
// Resolves per-build configuration values that are never committed to the repository.

import Foundation

/// Resolves configuration values that are supplied per build instead of being committed to source control.
///
/// Lookup order for every key:
/// 1. A process environment variable named after the key, which suits Xcode scheme environment variables.
/// 2. The app's Info.plist, which `Config/AsNeeded.xcconfig` fills from the gitignored `Config/Secrets.xcconfig`.
///
/// A value that is missing, blank, still an unexpanded `$(...)` build-setting placeholder, or still the `REPLACE_`
/// placeholder from `Config/Secrets.example.xcconfig` counts as absent, so a clean checkout with no secrets
/// configured builds and runs with the dependent feature switched off.
struct SecretManager: Sendable {
	// MARK: - Keys
	/// Every value the app can read. The raw value is both the environment variable and the build-setting name.
	enum Key: String, CaseIterable, Sendable {
		/// RevenueCat public SDK key. Without it tipping and subscriptions are unavailable.
		case revenueCatAPIKey = "REVENUECAT_API_KEY"

		/// The Info.plist entry the build injects this key into.
		var infoPlistKey: String {
			switch self {
			case .revenueCatAPIKey:
				return "RevenueCatAPIKey"
			}
		}
	}

	// MARK: - Errors
	enum SecretError: Error, Equatable, LocalizedError {
		case missingSecret(Key)

		var errorDescription: String? {
			switch self {
			case let .missingSecret(key):
				return "No value configured for \(key.rawValue). See Config/Secrets.example.xcconfig."
			}
		}
	}

	// MARK: - Properties
	static let shared = SecretManager()

	private let environment: [String: String]
	private let infoDictionary: [String: String]

	// MARK: - Initialization
	/// - Parameters:
	///   - environment: Process environment consulted first. Defaults to the current process.
	///   - infoDictionary: Info.plist contents consulted second. Defaults to the main bundle; non-string values are ignored.
	init(
		environment: [String: String] = ProcessInfo.processInfo.environment,
		infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
	) {
		self.environment = environment
		self.infoDictionary = infoDictionary.compactMapValues { $0 as? String }
	}

	// MARK: - Lookup
	/// Returns the configured value for `key`, or nil when this build supplies none.
	func secret(for key: Key) -> String? {
		if let value = Self.usableValue(environment[key.rawValue]) {
			return value
		}
		return Self.usableValue(infoDictionary[key.infoPlistKey])
	}

	/// Returns the configured value for `key`.
	/// - Throws: `SecretError.missingSecret` when this build supplies none.
	func getSecret(_ key: Key) throws -> String {
		guard let value = secret(for: key) else {
			throw SecretError.missingSecret(key)
		}
		return value
	}

	/// Prefix of the example file's placeholder value, which must never reach a live SDK.
	static let placeholderPrefix = "REPLACE_"

	/// Trims whitespace and rejects blanks, unexpanded build-setting placeholders such as `$(REVENUECAT_API_KEY)`,
	/// and the example file's `REPLACE_` placeholder.
	private static func usableValue(_ rawValue: String?) -> String? {
		guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
			return nil
		}
		guard !trimmed.hasPrefix("$("), !trimmed.hasPrefix(placeholderPrefix) else {
			return nil
		}
		return trimmed
	}
}

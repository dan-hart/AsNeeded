// SecretManagerTests.swift
// Covers how per-build secrets are resolved from the environment and Info.plist.

@testable import AsNeeded
import Foundation
import Testing

@Suite("SecretManager Tests")
struct SecretManagerTests {
	@Test("Environment variable wins over Info.plist")
	func environmentTakesPrecedence() throws {
		let manager = SecretManager(
			environment: ["REVENUECAT_API_KEY": "from-environment"],
			infoDictionary: ["RevenueCatAPIKey": "from-plist"]
		)
		#expect(try manager.getSecret(.revenueCatAPIKey) == "from-environment")
	}

	@Test("Info.plist supplies the value when the environment does not, trimmed")
	func infoPlistFallback() throws {
		let manager = SecretManager(environment: [:], infoDictionary: ["RevenueCatAPIKey": " from-plist \n"])
		#expect(try manager.getSecret(.revenueCatAPIKey) == "from-plist")
	}

	@Test("A blank environment value does not hide a configured Info.plist value")
	func blankEnvironmentFallsThrough() {
		let manager = SecretManager(
			environment: ["REVENUECAT_API_KEY": "   "],
			infoDictionary: ["RevenueCatAPIKey": "from-plist"]
		)
		#expect(manager.secret(for: .revenueCatAPIKey) == "from-plist")
	}

	@Test("Blank values everywhere count as missing")
	func blankValuesAreMissing() {
		let manager = SecretManager(environment: ["REVENUECAT_API_KEY": ""], infoDictionary: ["RevenueCatAPIKey": ""])
		#expect(manager.secret(for: .revenueCatAPIKey) == nil)
		#expect(throws: SecretManager.SecretError.missingSecret(.revenueCatAPIKey)) {
			try manager.getSecret(.revenueCatAPIKey)
		}
	}

	@Test("Unexpanded build setting placeholders count as missing")
	func placeholdersAreMissing() {
		let manager = SecretManager(environment: [:], infoDictionary: ["RevenueCatAPIKey": "$(REVENUECAT_API_KEY)"])
		#expect(manager.secret(for: .revenueCatAPIKey) == nil)
	}

	@Test("Non-string Info.plist entries are ignored")
	func nonStringPlistValuesAreIgnored() {
		let manager = SecretManager(environment: [:], infoDictionary: ["RevenueCatAPIKey": 42])
		#expect(manager.secret(for: .revenueCatAPIKey) == nil)
	}

	@Test("Missing secrets explain where to configure them")
	func missingSecretDescription() {
		let error = SecretManager.SecretError.missingSecret(.revenueCatAPIKey)
		#expect(error.errorDescription?.contains("REVENUECAT_API_KEY") == true)
		#expect(error.errorDescription?.contains("Secrets.example.xcconfig") == true)
	}
}

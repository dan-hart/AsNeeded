// FeatureToggleManagerTests.swift
// Tests for FeatureToggleManager

@testable import AsNeeded
import Foundation
import Testing

@Suite("FeatureToggleManager Tests", .tags(.unit))
@MainActor
struct FeatureToggleManagerTests {
	// MARK: - Initialization Tests

	@Test("FeatureToggleManager is a singleton")
	func singletonInstance() {
		let instance1 = FeatureToggleManager.shared
		let instance2 = FeatureToggleManager.shared

		#expect(instance1 === instance2)
	}

	@Test("FeatureToggleManager initializes successfully")
	func initialization() {
		let manager = FeatureToggleManager.shared

		#expect(manager != nil)
	}

	// MARK: - Feature Toggle Availability Tests

	@Test("Feature toggle availability in DEBUG builds")
	func featureToggleAvailabilityDebug() {
		let manager = FeatureToggleManager.shared
		// In test environment (DEBUG), feature toggles should be available
		#if DEBUG
			#expect(manager.isFeatureToggleAvailable == true)
		#endif
	}
}

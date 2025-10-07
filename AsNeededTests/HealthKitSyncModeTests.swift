// HealthKitSyncModeTests.swift
// Tests for HealthKit sync mode functionality and properties.

import Testing
@testable import AsNeeded
import Foundation

@Suite("HealthKit Sync Mode")
struct HealthKitSyncModeTests {

	// MARK: - Sync Mode Properties Tests

	@Test("All sync modes have unique raw values")
	func uniqueRawValues() {
		let modes: Set<String> = [
			HealthKitSyncMode.bidirectional.rawValue,
			HealthKitSyncMode.healthKitSOT.rawValue,
			HealthKitSyncMode.asNeededSOT.rawValue
		]

		#expect(modes.count == 3)
	}

	@Test("Raw values are lowercase snake_case or camelCase")
	func rawValueFormat() {
		let bidirectional = HealthKitSyncMode.bidirectional.rawValue
		let healthKitSOT = HealthKitSyncMode.healthKitSOT.rawValue
		let asNeededSOT = HealthKitSyncMode.asNeededSOT.rawValue

		// Should not contain spaces or special characters
		#expect(!bidirectional.contains(" "))
		#expect(!healthKitSOT.contains(" "))
		#expect(!asNeededSOT.contains(" "))

		// Should have reasonable length
		#expect(bidirectional.count > 3)
		#expect(healthKitSOT.count > 3)
		#expect(asNeededSOT.count > 3)
	}

	// MARK: - Display Name Tests

	@Test("All sync modes have user-friendly display names")
	func displayNames() {
		let bidirectional = HealthKitSyncMode.bidirectional.displayName
		let healthKitSOT = HealthKitSyncMode.healthKitSOT.displayName
		let asNeededSOT = HealthKitSyncMode.asNeededSOT.displayName

		// All should be non-empty
		#expect(bidirectional.count > 0)
		#expect(healthKitSOT.count > 0)
		#expect(asNeededSOT.count > 0)

		// Should be user-friendly (contains recognizable words)
		#expect(bidirectional.contains("Sync") || bidirectional.contains("Health"))
		#expect(healthKitSOT.contains("Health") || healthKitSOT.contains("Primary"))
		#expect(asNeededSOT.contains("AsNeeded") || asNeededSOT.contains("Primary"))
	}

	// MARK: - Description Tests

	@Test("All sync modes have detailed descriptions")
	func descriptions() {
		let bidirectional = HealthKitSyncMode.bidirectional.description
		let healthKitSOT = HealthKitSyncMode.healthKitSOT.description
		let asNeededSOT = HealthKitSyncMode.asNeededSOT.description

		// Descriptions should be substantial
		#expect(bidirectional.count > 20)
		#expect(healthKitSOT.count > 20)
		#expect(asNeededSOT.count > 20)

		// Should contain relevant keywords
		#expect(bidirectional.contains("sync") || bidirectional.contains("both"))
		#expect(healthKitSOT.contains("Health") || healthKitSOT.contains("manage"))
		#expect(asNeededSOT.contains("AsNeeded") || asNeededSOT.contains("backup"))
	}

	// MARK: - Pros Tests

	@Test("Bidirectional mode has pros list")
	func bidirectionalPros() {
		let pros = HealthKitSyncMode.bidirectional.pros
		#expect(pros.count > 0)
		#expect(pros.allSatisfy { $0.count > 5 })
	}

	@Test("HealthKit SOT mode has pros list")
	func healthKitSOTPros() {
		let pros = HealthKitSyncMode.healthKitSOT.pros
		#expect(pros.count > 0)
		#expect(pros.allSatisfy { $0.count > 5 })
	}

	@Test("AsNeeded SOT mode has pros list")
	func asNeededSOTPros() {
		let pros = HealthKitSyncMode.asNeededSOT.pros
		#expect(pros.count > 0)
		#expect(pros.allSatisfy { $0.count > 5 })
	}

	// MARK: - Cons Tests

	@Test("Bidirectional mode has cons list")
	func bidirectionalCons() {
		let cons = HealthKitSyncMode.bidirectional.cons
		#expect(cons.count > 0)
		#expect(cons.allSatisfy { $0.count > 5 })
	}

	@Test("HealthKit SOT mode has cons list")
	func healthKitSOTCons() {
		let cons = HealthKitSyncMode.healthKitSOT.cons
		#expect(cons.count > 0)
		#expect(cons.allSatisfy { $0.count > 5 })
	}

	@Test("AsNeeded SOT mode has cons list")
	func asNeededSOTCons() {
		let cons = HealthKitSyncMode.asNeededSOT.cons
		#expect(cons.count > 0)
		#expect(cons.allSatisfy { $0.count > 5 })
	}

	// MARK: - Data Export Tests

	@Test("Data export availability is correct for each mode")
	func dataExportAvailability() {
		// Bidirectional allows export (data stored locally)
		#expect(HealthKitSyncMode.bidirectional.allowsDataExport == true)

		// HealthKit SOT does NOT allow export (data lives only in HealthKit)
		#expect(HealthKitSyncMode.healthKitSOT.allowsDataExport == false)

		// AsNeeded SOT allows export (data stored locally)
		#expect(HealthKitSyncMode.asNeededSOT.allowsDataExport == true)
	}

	// MARK: - Local Storage Tests

	@Test("Local storage writing is correct for each mode")
	func localStorageWriting() {
		// Bidirectional writes to local storage
		#expect(HealthKitSyncMode.bidirectional.writesToLocalStorage == true)

		// HealthKit SOT does NOT write to local storage
		#expect(HealthKitSyncMode.healthKitSOT.writesToLocalStorage == false)

		// AsNeeded SOT writes to local storage
		#expect(HealthKitSyncMode.asNeededSOT.writesToLocalStorage == true)
	}

	// MARK: - Codable Tests

	@Test("Sync modes can be encoded and decoded")
	func codableSupport() throws {
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		// Test bidirectional
		let bidirectionalData = try encoder.encode(HealthKitSyncMode.bidirectional)
		let decodedBidirectional = try decoder.decode(HealthKitSyncMode.self, from: bidirectionalData)
		#expect(decodedBidirectional == .bidirectional)

		// Test healthKitSOT
		let healthKitSOTData = try encoder.encode(HealthKitSyncMode.healthKitSOT)
		let decodedHealthKitSOT = try decoder.decode(HealthKitSyncMode.self, from: healthKitSOTData)
		#expect(decodedHealthKitSOT == .healthKitSOT)

		// Test asNeededSOT
		let asNeededSOTData = try encoder.encode(HealthKitSyncMode.asNeededSOT)
		let decodedAsNeededSOT = try decoder.decode(HealthKitSyncMode.self, from: asNeededSOTData)
		#expect(decodedAsNeededSOT == .asNeededSOT)
	}

	@Test("Sync mode can be initialized from raw value")
	func rawValueInitialization() {
		// Valid raw values should initialize
		let bidirectional = HealthKitSyncMode(rawValue: "bidirectional")
		#expect(bidirectional == .bidirectional)

		let healthKitSOT = HealthKitSyncMode(rawValue: "healthKitSOT")
		#expect(healthKitSOT == .healthKitSOT)

		let asNeededSOT = HealthKitSyncMode(rawValue: "asNeededSOT")
		#expect(asNeededSOT == .asNeededSOT)

		// Invalid raw value should return nil
		let invalid = HealthKitSyncMode(rawValue: "invalid_mode")
		#expect(invalid == nil)
	}

	// MARK: - Equatable Tests

	@Test("Sync modes are correctly equatable")
	func equalityComparison() {
		#expect(HealthKitSyncMode.bidirectional == .bidirectional)
		#expect(HealthKitSyncMode.healthKitSOT == .healthKitSOT)
		#expect(HealthKitSyncMode.asNeededSOT == .asNeededSOT)

		#expect(HealthKitSyncMode.bidirectional != .healthKitSOT)
		#expect(HealthKitSyncMode.healthKitSOT != .asNeededSOT)
		#expect(HealthKitSyncMode.asNeededSOT != .bidirectional)
	}

	// MARK: - Hashable Tests

	@Test("Sync modes are hashable and can be used in sets")
	func hashableSupport() {
		let modes: Set<HealthKitSyncMode> = [
			.bidirectional,
			.healthKitSOT,
			.asNeededSOT
		]

		#expect(modes.count == 3)
		#expect(modes.contains(.bidirectional))
		#expect(modes.contains(.healthKitSOT))
		#expect(modes.contains(.asNeededSOT))
	}

	// MARK: - Case Iteration Tests

	@Test("All sync mode cases are accessible")
	func allCases() {
		let allModes: [HealthKitSyncMode] = [
			.bidirectional,
			.healthKitSOT,
			.asNeededSOT
		]

		#expect(allModes.count == 3)

		// All should have complete properties
		for mode in allModes {
			#expect(mode.displayName.count > 0)
			#expect(mode.description.count > 0)
			#expect(mode.pros.count > 0)
			#expect(mode.cons.count > 0)
		}
	}

	// MARK: - Business Logic Tests

	@Test("HealthKit SOT mode prevents data export correctly")
	func healthKitSOTPreventions() {
		let mode = HealthKitSyncMode.healthKitSOT

		// Should not allow export
		#expect(mode.allowsDataExport == false)

		// Should not write to local storage
		#expect(mode.writesToLocalStorage == false)

		// Should have relevant cons mentioning this limitation
		let consText = mode.cons.joined(separator: " ").lowercased()
		#expect(consText.contains("export") || consText.contains("data"))
	}

	@Test("Bidirectional mode enables full functionality")
	func bidirectionalFullFunctionality() {
		let mode = HealthKitSyncMode.bidirectional

		// Should allow export
		#expect(mode.allowsDataExport == true)

		// Should write to local storage
		#expect(mode.writesToLocalStorage == true)

		// Pros should mention sync benefits
		let prosText = mode.pros.joined(separator: " ").lowercased()
		#expect(prosText.contains("sync") || prosText.contains("data"))
	}

	@Test("AsNeeded SOT mode preserves local control")
	func asNeededSOTLocalControl() {
		let mode = HealthKitSyncMode.asNeededSOT

		// Should allow export (local storage)
		#expect(mode.allowsDataExport == true)

		// Should write to local storage
		#expect(mode.writesToLocalStorage == true)

		// Description should mention AsNeeded as primary
		let description = mode.description.lowercased()
		#expect(description.contains("asneeded") || description.contains("primary") || description.contains("backup"))
	}

	// MARK: - User Experience Tests

	@Test("Sync mode UI text is clear and concise")
	func uiTextQuality() {
		let modes = [
			HealthKitSyncMode.bidirectional,
			.healthKitSOT,
			.asNeededSOT
		]

		for mode in modes {
			// Display names should be under 30 characters for UI
			#expect(mode.displayName.count < 30)

			// Descriptions should be under 200 characters for UI cards
			#expect(mode.description.count < 200)

			// Pros/cons should be concise (under 100 chars each)
			for pro in mode.pros {
				#expect(pro.count < 100)
			}
			for con in mode.cons {
				#expect(con.count < 100)
			}
		}
	}
}

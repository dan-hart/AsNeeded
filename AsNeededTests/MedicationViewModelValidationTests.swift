// MedicationViewModelValidationTests.swift
// Tests for ViewModel validation of deleted medications

import Testing
import Foundation
import ANModelKit
@testable import AsNeeded

@Suite("Medication ViewModel Validation Tests", .tags(.viewModel, .validation, .unit))
@MainActor
struct MedicationViewModelValidationTests {
	private var dataStore: DataStore
	
	init() async throws {
		// Create test instance with isolated storage
		dataStore = DataStore(testIdentifier: "ViewModelValidationTests")
		// Clear any existing test data
		try await dataStore.clearAllData()
	}
	
	// MARK: - History ViewModel Tests
	
	@Test("History ViewModel keeps valid selected medication on init")
	func historyViewModelKeepsValidSelection() async throws {
		// Given - Add a medication and set it as selected
		let medication = ANMedicationConcept(
			clinicalName: "Valid Med",
			nickname: nil
		)
		try await dataStore.addMedication(medication)
		UserDefaults.standard.set(medication.id.uuidString, forKey: "historySelectedMedicationID")
		
		// When - Initialize the view model
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)
		
		// Then - Valid selection should be kept
		#expect(viewModel.selectedMedicationID == medication.id,
			"Valid medication ID should be preserved")
		#expect(viewModel.selectedMedication?.clinicalName == "Valid Med",
			"Should be able to retrieve the selected medication")
	}

	@Test("Trends ViewModel keeps valid selected medication on init")
	func trendsViewModelKeepsValidSelection() async throws {
		// Given - Add a medication and set it as selected
		let medication = ANMedicationConcept(
			clinicalName: "Valid Med",
			nickname: nil,
			prescribedUnit: .milligram
		)
		try await dataStore.addMedication(medication)
		UserDefaults.standard.set(medication.id.uuidString, forKey: "trendsSelectedMedicationID")
		
		// When - Initialize the view model
		let viewModel = MedicationTrendsViewModel(dataStore: dataStore)
		
		// Then - Valid selection should be kept
		#expect(viewModel.selectedMedicationID == medication.id,
			"Valid medication ID should be preserved")
		#expect(viewModel.selectedMedication?.clinicalName == "Valid Med",
			"Should be able to retrieve the selected medication")
	}
	
	@Test("Trends ViewModel returns empty data for non-existent medication")
	func trendsViewModelHandlesNonExistentMedication() async throws {
		// Given - Initialize with non-existent medication ID
		let nonExistentID = UUID()
		let viewModel = MedicationTrendsViewModel(
			dataStore: dataStore,
			selectedMedicationID: nonExistentID
		)
		
		// When - Access computed properties
		let events = viewModel.events
		let dailyTotals = viewModel.dailyTotals()
		let average = viewModel.averagePerDay()
		
		// Then - Should return safe defaults
		#expect(events.isEmpty, "Should return empty events for non-existent medication")
		#expect(dailyTotals.isEmpty, "Should return empty daily totals")
		#expect(average == 0, "Should return 0 average for non-existent medication")
	}
}

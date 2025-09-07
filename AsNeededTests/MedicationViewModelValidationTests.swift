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
	
	@Test("History ViewModel validates selected medication exists on init")
	func historyViewModelValidatesOnInit() async throws {
		// Given - Set a non-existent medication ID in UserDefaults
		let nonExistentID = UUID()
		UserDefaults.standard.set(nonExistentID.uuidString, forKey: "historySelectedMedicationID")
		
		// When - Initialize the view model
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)
		
		// Then - Invalid selection should be cleared
		#expect(viewModel.selectedMedicationID == nil,
			"Non-existent medication ID should be cleared on init")
		#expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == "",
			"AppStorage should be cleared for invalid medication")
	}
	
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
	
	@Test("History ViewModel clears selection when medication is deleted")
	func historyViewModelClearsDeletedMedication() async throws {
		// Given - Add medication and select it
		let medication = ANMedicationConcept(
			clinicalName: "To Delete",
			nickname: nil
		)
		try await dataStore.addMedication(medication)
		
		let viewModel = MedicationHistoryViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication.id
		)
		
		#expect(viewModel.selectedMedicationID == medication.id)
		
		// When - Delete the medication and re-validate
		try await dataStore.deleteMedication(medication)
		viewModel.validateSelectedMedication()
		
		// Then - Selection should be cleared
		#expect(viewModel.selectedMedicationID == nil,
			"Deleted medication should be cleared from selection")
	}
	
	// MARK: - Trends ViewModel Tests
	
	@Test("Trends ViewModel validates selected medication exists on init")
	func trendsViewModelValidatesOnInit() async throws {
		// Given - Set a non-existent medication ID in UserDefaults
		let nonExistentID = UUID()
		UserDefaults.standard.set(nonExistentID.uuidString, forKey: "trendsSelectedMedicationID")
		
		// When - Initialize the view model
		let viewModel = MedicationTrendsViewModel(dataStore: dataStore)
		
		// Then - Invalid selection should be cleared
		#expect(viewModel.selectedMedicationID == nil,
			"Non-existent medication ID should be cleared on init")
		#expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == "",
			"AppStorage should be cleared for invalid medication")
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
	
	// MARK: - Integration Tests
	
	@Test("ViewModels handle medication deletion workflow correctly")
	func viewModelsHandleDeletionWorkflow() async throws {
		// Given - Setup medications and select one in both view models
		let medication1 = ANMedicationConcept(clinicalName: "Med 1", nickname: nil)
		let medication2 = ANMedicationConcept(clinicalName: "Med 2", nickname: nil)
		
		try await dataStore.addMedication(medication1)
		try await dataStore.addMedication(medication2)
		
		// Create events for medication1
		let event = ANEventConcept(
			eventType: .doseTaken,
			medication: medication1,
			dose: ANDoseConcept(amount: 10.0, unit: .milligram),
			date: Date()
		)
		try await dataStore.addEvent(event)
		
		// Initialize view models with medication1 selected
		let historyVM = MedicationHistoryViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication1.id
		)
		let trendsVM = MedicationTrendsViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication1.id
		)
		
		#expect(historyVM.selectedMedicationID == medication1.id)
		#expect(trendsVM.selectedMedicationID == medication1.id)
		#expect(!historyVM.groupedHistory.isEmpty, "Should have history for medication1")
		
		// When - Delete medication1
		try await dataStore.deleteMedication(medication1)
		
		// Create new view models (simulating view refresh)
		let newHistoryVM = MedicationHistoryViewModel(dataStore: dataStore)
		let newTrendsVM = MedicationTrendsViewModel(dataStore: dataStore)
		
		// Then - ViewModels should have cleared the deleted medication
		#expect(newHistoryVM.selectedMedicationID == nil,
			"History should clear deleted medication on init")
		#expect(newTrendsVM.selectedMedicationID == nil,
			"Trends should clear deleted medication on init")
		#expect(newHistoryVM.groupedHistory.isEmpty,
			"Should have no history after medication deletion")
		
		// Medication2 should still be available
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.medications.first?.clinicalName == "Med 2")
	}
	
	@Test("Concurrent deletion and selection handles race conditions")
	func concurrentDeletionAndSelection() async throws {
		// Given - Add multiple medications
		let medications = (0..<5).map { i in
			ANMedicationConcept(clinicalName: "Med \(i)", nickname: nil)
		}
		
		for med in medications {
			try await dataStore.addMedication(med)
		}
		
		// When - Simulate concurrent operations
		let medicationToDelete = medications[2]
		
		// Set as selected just before deletion (race condition)
		UserDefaults.standard.set(medicationToDelete.id.uuidString, forKey: "historySelectedMedicationID")
		
		// Delete the medication
		try await dataStore.deleteMedication(medicationToDelete)
		
		// Initialize view model after deletion
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)
		
		// Then - Should handle gracefully
		#expect(viewModel.selectedMedicationID == nil,
			"Should clear selection for deleted medication even in race condition")
		#expect(dataStore.medications.count == 4,
			"Other medications should remain")
	}
}
// MedicationIDMismatchTests.swift
// Tests for handling medication ID mismatches in imported data

import Testing
import Foundation
import ANModelKit
@testable import AsNeeded

@Suite("Medication ID Mismatch Tests", .tags(.dataStore, .persistence))
@MainActor
struct MedicationIDMismatchTests {
	private var dataStore: DataStore
	
	init() async throws {
		// Create test instance with isolated storage
		dataStore = DataStore(testIdentifier: "MedicationIDMismatchTests")
		// Clear any existing test data
		try await dataStore.clearAllData()
	}
	
	// MARK: - Import Tests
	
	@Test("Import handles events with mismatched medication IDs", .disabled("JSON import with medication references in events not fully supported"))
	func importHandlesMismatchedMedicationIDs() async throws {
		// Given - JSON data with a medication and events where one has a different medication ID
		let jsonData = """
		{
			"medications": [
				{
					"id": "DA2D2903-DB45-4840-BD8B-2E8729B21875",
					"clinicalName": "Alprazolam",
					"nickname": "Xanax",
					"quantity": 100.0
				}
			],
			"events": [
				{
					"id": "EVENT-1",
					"eventType": "dose_taken",
					"date": "2022-01-01T12:00:00Z",
					"medication": {
						"id": "DA2D2903-DB45-4840-BD8B-2E8729B21875",
						"clinicalName": "Alprazolam"
					},
					"dose": {
						"amount": 1.0,
						"unit": "milligram"
					}
				},
				{
					"id": "EVENT-2",
					"eventType": "dose_taken",
					"date": "2022-01-02T12:00:00Z",
					"medication": {
						"id": "2D3D7CC5-09C1-46BF-8EFD-71EB956F33AF",
						"clinicalName": "Alprazolam"
					},
					"dose": {
						"amount": 2.0,
						"unit": "milligram"
					}
				}
			],
			"exportDate": "2022-01-01T12:00:00Z",
			"appVersion": "1.0.0"
		}
		""".data(using: .utf8)!
		
		// When - Import the data
		try await dataStore.importDataFromJSON(jsonData)
		
		// Then - Both events should be imported with corrected medication references
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.events.count == 2)
		
		// All events should reference the same medication ID
		let medicationID = dataStore.medications.first?.id
		for event in dataStore.events {
			#expect(event.medication?.id == medicationID,
				"Event should have corrected medication ID")
		}
	}
	
	@Test("Import skips events with non-existent medications", .disabled("JSON import with medication references in events not fully supported"))
	func importSkipsEventsWithNonExistentMedications() async throws {
		// Given - JSON with events referencing medications not in the import
		let jsonData = """
		{
			"medications": [
				{
					"id": "MED-1",
					"clinicalName": "Ibuprofen",
					"nickname": "Advil",
					"quantity": 50.0
				}
			],
			"events": [
				{
					"id": "EVENT-1",
					"eventType": "dose_taken",
					"date": "2022-01-01T12:00:00Z",
					"medication": {
						"id": "MED-NONEXISTENT",
						"clinicalName": "Aspirin"
					},
					"dose": {
						"amount": 1.0,
						"unit": "tablet"
					}
				}
			],
			"exportDate": "2022-01-01T12:00:00Z",
			"appVersion": "1.0.0"
		}
		""".data(using: .utf8)!
		
		// When - Import the data
		try await dataStore.importDataFromJSON(jsonData)
		
		// Then - Medication imported but event skipped
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.events.count == 0,
			"Event with non-existent medication should be skipped")
	}
	
	// MARK: - Trends ViewModel Tests
	
	@Test("Trends ViewModel filters out events with mismatched medication IDs")
	func trendsViewModelFiltersMismatchedEvents() async throws {
		// Given - Setup data with correct medication
		let medication = ANMedicationConcept(
			id: UUID(),
			clinicalName: "Test Med",
			nickname: nil,
			prescribedUnit: .milligram
		)
		try await dataStore.addMedication(medication)
		
		// Add a correct event
		let correctEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 1, unit: .milligram),
			date: Date()
		)
		try await dataStore.addEvent(correctEvent)
		
		// Create a mismatched event (different medication ID)
		let mismatchedMedication = ANMedicationConcept(
			id: UUID(), // Different ID
			clinicalName: medication.clinicalName,
			nickname: medication.nickname,
			prescribedUnit: medication.prescribedUnit
		)
		let mismatchedEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: mismatchedMedication,
			dose: ANDoseConcept(amount: 2, unit: .milligram),
			date: Date()
		)
		try await dataStore.addEvent(mismatchedEvent)
		
		// When - Create trends view model
		let viewModel = MedicationTrendsViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication.id
		)
		
		// Then - Only the correct event should be included
		#expect(viewModel.events.count == 1,
			"Should only include events with matching medication ID")
		#expect(viewModel.events.first?.medication?.id == medication.id,
			"Event should have the correct medication ID")
	}
	
	@Test("Trends ViewModel handles empty events gracefully")
	func trendsViewModelHandlesEmptyEvents() async throws {
		// Given - Medication with no events
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			nickname: nil,
			quantity: 50
		)
		try await dataStore.addMedication(medication)
		
		// When - Create trends view model
		let viewModel = MedicationTrendsViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication.id
		)
		
		// Then - Should handle gracefully
		#expect(viewModel.events.isEmpty)
		#expect(viewModel.dailyTotals().isEmpty)
		#expect(viewModel.averagePerDay() == 0)
		
		// Calendar heatmap should generate empty days array when no preferredUnit
		let heatmapData = viewModel.calendarHeatmapData()
		#expect(heatmapData.isEmpty) // No data when no preferred unit
		
		// Note: calendarHeatmapData returns empty array when preferredUnit is nil
		// This is expected behavior since we can't calculate totals without a unit
	}
	
	@Test("Import matches medications by name when IDs differ", .disabled("JSON import with medication references in events not fully supported"))
	func importMatchesMedicationsByName() async throws {
		// Given - JSON where events have same medication name but different ID
		let jsonData = """
		{
			"medications": [
				{
					"id": "CORRECT-ID",
					"clinicalName": "Alprazolam",
					"nickname": "Xanax",
					"quantity": 100.0
				}
			],
			"events": [
				{
					"id": "EVENT-1",
					"eventType": "dose_taken",
					"date": "2022-01-01T12:00:00Z",
					"medication": {
						"id": "WRONG-ID",
						"clinicalName": "Alprazolam"
					},
					"dose": {
						"amount": 1.0,
						"unit": "milligram"
					}
				}
			],
			"exportDate": "2022-01-01T12:00:00Z",
			"appVersion": "1.0.0"
		}
		""".data(using: .utf8)!
		
		// When - Import the data
		try await dataStore.importDataFromJSON(jsonData)
		
		// Then - Event should be matched to medication by name
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.events.count == 1)
		
		let medication = dataStore.medications.first!
		let event = dataStore.events.first!
		
		#expect(event.medication?.id == medication.id,
			"Event medication ID should be corrected to match imported medication")
		#expect(event.medication?.clinicalName == "Alprazolam")
		#expect(event.medication?.nickname == "Xanax")
	}
}
// MedicationIDMismatchTests.swift
// Tests for handling medication ID mismatches in imported data

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Medication ID Mismatch Tests", .serialized, .tags(.dataStore, .persistence))
@MainActor
struct MedicationIDMismatchTests {
    private var dataStore: DataStore

    init() async throws {
        // Create test instance with isolated storage
        dataStore = DataStore(testIdentifier: "MedicationIDMismatchTests")
        // Clear any existing test data
        try await dataStore.clearUserData()
    }

    // MARK: - Import Tests

	@Test("Import handles events with mismatched medication IDs")
	func importHandlesMismatchedMedicationIDs() async throws {
		let medication = ANMedicationConcept(clinicalName: "Example medication", nickname: "Example nickname", quantity: 100)
		let reconstructed = ANMedicationConcept(clinicalName: medication.clinicalName, nickname: medication.nickname)
		let correct = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 1, unit: .milligram), date: Date())
		let mismatched = ANEventConcept(eventType: .doseTaken, medication: reconstructed, dose: ANDoseConcept(amount: 2, unit: .milligram), date: Date())
		try await dataStore.importDataFromJSON(encoded(medications: [medication], events: [correct, mismatched]))
		#expect(dataStore.medications.map(\.id) == [medication.id])
		#expect(Set(dataStore.events.map(\.id)) == Set([correct.id, mismatched.id]))
		#expect(dataStore.events.allSatisfy { $0.medication?.id == medication.id })
	}

	@Test("Import rejects unresolved history before replacing existing records")
	func importRejectsNonExistentMedications() async throws {
		let current = ANMedicationConcept(clinicalName: "Existing example", quantity: 10)
		let retained = ANEventConcept(eventType: .doseTaken, medication: current, date: Date())
		try await dataStore.addMedication(current)
		try await dataStore.addEvent(retained, shouldRecordForReview: false)
		let incoming = ANMedicationConcept(clinicalName: "Incoming example")
		let missing = ANMedicationConcept(clinicalName: "Missing example")
		let invalid = ANEventConcept(eventType: .doseTaken, medication: missing, date: Date())
		let data = try encoded(medications: [incoming], events: [invalid])
		await #expect(throws: DataImportError.self) { try await dataStore.importDataFromJSON(data) }
		#expect(dataStore.medications == [current])
		#expect(dataStore.events.map(\.id) == [retained.id])
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

	@Test("Import matches an unambiguous medication name and nickname when IDs differ")
	func importMatchesMedicationsByName() async throws {
		let medication = ANMedicationConcept(clinicalName: "Example medication", nickname: "Example nickname", quantity: 100)
		let reconstructed = ANMedicationConcept(clinicalName: medication.clinicalName, nickname: medication.nickname)
		let event = ANEventConcept(eventType: .doseTaken, medication: reconstructed, dose: ANDoseConcept(amount: 1, unit: .milligram), date: Date())
		try await dataStore.importDataFromJSON(encoded(medications: [medication], events: [event]))
		#expect(dataStore.medications.map(\.id) == [medication.id])
		#expect(dataStore.events.map(\.id) == [event.id])
		#expect(dataStore.events.first?.medication?.id == medication.id)
		#expect(dataStore.events.first?.medication?.clinicalName == medication.clinicalName)
		#expect(dataStore.events.first?.medication?.nickname == medication.nickname)
	}

	private func encoded(medications: [ANMedicationConcept], events: [ANEventConcept]) throws -> Data {
		let export = DataExport(medications: medications, events: events, exportDate: Date(), appVersion: "1.1.2", dataVersion: "1.0", settings: nil)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}
}

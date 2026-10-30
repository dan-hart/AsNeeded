// MedicationHistoryViewModelTests.swift
// Unit tests for MedicationHistoryViewModel dose editing functionality

import ANModelKit
@testable import AsNeeded
import Foundation
import Combine
import Testing

@MainActor
@Suite("MedicationHistoryViewModel Dose Editing Tests", .serialized)
struct MedicationHistoryViewModelTests {
	// MARK: - Test Setup Helpers

	private func clearStoredSelection() {
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.historySelectedMedicationID)
	}

	private func createTestMedication(quantity: Double = 10.0) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: "Pain Relief",
			quantity: quantity,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2.0
		)
	}

	private func createTestEvent(medication: ANMedicationConcept, amount: Double, unit: ANUnitConcept) -> ANEventConcept {
		let dose = ANDoseConcept(amount: amount, unit: unit)
		return ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: dose,
			date: Date()
		)
	}

	@Test("EnsureValidSelection defaults to all medications")
	func ensureValidSelectionDefaultsToAll() async throws {
		clearStoredSelection()
		let medication = createTestMedication()
		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-SelectionAll")
		try? await dataStore.addMedication(medication)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		#expect(viewModel.selectedMedicationID == "all")
		#expect(viewModel.isShowingAllMedications)
	}

	@Test("Selected medication resolves when a medication ID is provided")
	func selectedMedicationResolvesProvidedID() async throws {
		clearStoredSelection()
		let medication = createTestMedication()
		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-SelectionSpecific")
		try? await dataStore.addMedication(medication)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		#expect(viewModel.selectedMedication?.id == medication.id)
		#expect(viewModel.isShowingAllMedications == false)
	}

	@Test("Grouped history filters to selected medication and sorts newest day first")
	func groupedHistoryFiltersAndSorts() async throws {
		clearStoredSelection()
		let med1 = createTestMedication(quantity: 8)
		let med2 = ANMedicationConcept(
			clinicalName: "Cetirizine",
			quantity: 20,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 1
		)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-GroupedHistory")
		try? await dataStore.addMedication(med1)
		try? await dataStore.addMedication(med2)

		let todayEvent = createTestEvent(medication: med1, amount: 1.0, unit: .tablet)
		let yesterdayEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: med1,
			dose: ANDoseConcept(amount: 1.0, unit: .tablet),
			date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
		)
		let otherMedicationEvent = createTestEvent(medication: med2, amount: 1.0, unit: .tablet)

		try? await dataStore.addEvent(todayEvent)
		try? await dataStore.addEvent(yesterdayEvent)
		try? await dataStore.addEvent(otherMedicationEvent)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: med1.id.uuidString)

		#expect(viewModel.groupedHistory.count == 2)
		#expect(viewModel.groupedHistory.first?.entries.first?.medication?.id == med1.id)
		#expect(viewModel.groupedHistory.allSatisfy { $0.entries.allSatisfy { $0.medication?.id == med1.id } })
	}

	@Test("History cache follows selection changes and replacements with the same event identity")
	func groupedHistoryInvalidatesForSelectionAndEventEdits() async throws {
		let first = createTestMedication()
		let second = createTestMedication()
		let store = DataStore(testIdentifier: "History-Cache-\(UUID().uuidString)")
		try await store.addMedication(first)
		try await store.addMedication(second)
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: first.id.uuidString)
		let event = createTestEvent(medication: first, amount: 1, unit: .tablet)
		let secondEvent = createTestEvent(medication: second, amount: 2, unit: .tablet)
		model.events = [event, secondEvent]
		#expect(model.groupedHistory.flatMap(\.entries).map(\.id) == [event.id])
		model.selectedMedicationID = second.id.uuidString
		#expect(model.groupedHistory.flatMap(\.entries).map(\.id) == [secondEvent.id])
		var edited = secondEvent
		edited.date = Calendar.current.date(byAdding: .day, value: -2, to: event.date) ?? event.date
		edited.dose = ANDoseConcept(amount: 3, unit: .tablet)
		model.events = [event, edited]
		#expect(model.groupedHistory.first?.day == Calendar.current.startOfDay(for: edited.date))
		#expect(model.groupedHistory.first?.entries.first?.dose?.amount == 3)
		model.selectedMedicationID = "all"
		#expect(model.groupedHistory.flatMap(\.entries).count == 2)
	}

	@Test("History observes newly saved doses without polling", .timeLimit(.minutes(1)))
	func historyObservesSavedDose() async throws {
		let medication = createTestMedication(quantity: 10)
		let store = DataStore(testIdentifier: "History-ObservedDose-\(UUID().uuidString)")
		try await store.addMedication(medication)
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: medication.id.uuidString)
		#expect(model.groupedHistory.isEmpty)
		let event = createTestEvent(medication: medication, amount: 2, unit: .tablet)
		let updates = AsyncStream<[ANEventConcept]>.makeStream(bufferingPolicy: .bufferingNewest(1))
		let subscription = model.$events.sink { updates.continuation.yield($0) }
		let observation = Task { @MainActor in
			for await events in updates.stream {
				if events.contains(where: { $0.id == event.id }) { return }
			}
		}
		defer {
			observation.cancel()
			subscription.cancel()
			updates.continuation.finish()
		}
		try await store.recordDose(event)
		await observation.value
		#expect(model.groupedHistory.first?.entries.first?.id == event.id)
		#expect(model.medications.first?.quantity == 8)
	}

	@Test("History receives a cold store load and keeps the requested medication", .timeLimit(.minutes(1)))
	func historyObservesColdStoreLoad() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("History-ColdLoad-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }
		let medication = createTestMedication()
		let writer = DataStore(storageDirectory: directory)
		try await writer.addMedication(medication)
		let event = createTestEvent(medication: medication, amount: 1, unit: .tablet)
		try await writer.addEvent(event)
		let reader = DataStore(storageDirectory: directory)
		let model = MedicationHistoryViewModel(dataStore: reader, selectedMedicationID: medication.id.uuidString)
		let updates = AsyncStream<[ANEventConcept]>.makeStream(bufferingPolicy: .bufferingNewest(1))
		let subscription = model.$events.sink { updates.continuation.yield($0) }
		defer {
			subscription.cancel()
			updates.continuation.finish()
		}
		for await events in updates.stream {
			if events.contains(where: { $0.id == event.id }) { break }
		}
		#expect(model.selectedMedicationID == medication.id.uuidString)
		#expect(model.groupedHistory.first?.entries.first?.id == event.id)
	}

	@Test("History clock refresh redraws date labels without a store mutation")
	func clockRefreshPublishesPresentationChange() async throws {
		let store = DataStore(testIdentifier: "History-Clock-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: medication.id.uuidString, notificationCenter: NotificationCenter())
		var refreshes = 0
		let subscription = model.objectWillChange.sink { refreshes += 1 }
		defer { subscription.cancel() }
		model.refreshForClockChange()
		#expect(refreshes == 1)
		#expect(model.groupedHistory.isEmpty)
	}

	@Test("History foreground refresh loads doses saved by another store")
	func foregroundRefreshLoadsExternalDose() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("History-Foreground-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }
		let reader = DataStore(storageDirectory: directory)
		let medication = createTestMedication(quantity: 10)
		try await reader.addMedication(medication)
		let model = MedicationHistoryViewModel(dataStore: reader, selectedMedicationID: medication.id.uuidString, notificationCenter: NotificationCenter())
		await model.refreshAfterForeground()
		#expect(model.groupedHistory.isEmpty)
		let writer = DataStore(storageDirectory: directory)
		let event = createTestEvent(medication: medication, amount: 2, unit: .tablet)
		try await writer.recordDose(event)
		await model.refreshAfterForeground()
		#expect(model.groupedHistory.first?.entries.first?.id == event.id)
		#expect(model.medications.first?.quantity == 8)
	}

	// MARK: - Dose Increase Tests

	@Test("A missing history entry reports failure without changing medication quantity")
	func missingEntryCannotChangeQuantity() async throws {
		let medication = createTestMedication(quantity: 10)
		let event = createTestEvent(medication: medication, amount: 2, unit: .tablet)
		let dataStore = DataStore(testIdentifier: "History-MissingEntry-\(UUID().uuidString)")
		try await dataStore.addMedication(medication)
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		let saved = await viewModel.updateEvent(event, newDate: event.date, newAmount: 3, newUnit: .tablet)

		#expect(!saved)
		#expect(viewModel.mutationError != nil)
		#expect(!viewModel.isMutating)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first(where: { $0.id == medication.id })?.quantity == 10)
	}

	@Test("Deleting an entry twice restores quantity only once and reports the second failure")
	func duplicateDeleteCannotRestoreQuantityTwice() async throws {
		let medication = createTestMedication(quantity: 5)
		let event = createTestEvent(medication: medication, amount: 2, unit: .tablet)
		let dataStore = DataStore(testIdentifier: "History-DuplicateDelete-\(UUID().uuidString)")
		try await dataStore.addMedication(medication)
		try await dataStore.addEvent(event)
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		let firstDeletion = await viewModel.deleteEvent(event)
		let secondDeletion = await viewModel.deleteEvent(event)

		#expect(firstDeletion)
		#expect(!secondDeletion)
		#expect(viewModel.mutationError != nil)
		#expect(!viewModel.isMutating)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first(where: { $0.id == medication.id })?.quantity == 7)
	}

	@Test("Update event with increased dose decreases medication quantity")
	func updateEventIncreaseDoseDecreasesQuantity() async throws {
		// Given: medication with quantity 10, event with dose 2
		let medication = createTestMedication(quantity: 10.0)
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event dose from 2 to 3
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 3.0, newUnit: .tablet)

		// Then: medication quantity should decrease by 1 (10 - 1 = 9)
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == 9.0, "Quantity should decrease from 10 to 9 when dose increases from 2 to 3")
	}

	// MARK: - Dose Decrease Tests

	@Test("Update event with decreased dose increases medication quantity")
	func updateEventDecreaseDoseIncreasesQuantity() async throws {
		// Given: medication with quantity 10, event with dose 3
		let medication = createTestMedication(quantity: 10.0)
		let event = createTestEvent(medication: medication, amount: 3.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event dose from 3 to 2
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .tablet)

		// Then: medication quantity should increase by 1 (10 + 1 = 11)
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == 11.0, "Quantity should increase from 10 to 11 when dose decreases from 3 to 2")
	}

	// MARK: - No Dose Change Tests

	@Test("Update event with same dose keeps quantity unchanged")
	func updateEventSameDoseKeepsQuantityUnchanged() async throws {
		// Given: medication with quantity 10, event with dose 2
		let medication = createTestMedication(quantity: 10.0)
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event with same dose (2.0)
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .tablet)

		// Then: medication quantity should remain 10
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == 10.0, "Quantity should remain 10 when dose doesn't change")
	}

	// MARK: - Date Change Tests

	@Test("Update event changes date correctly")
	func updateEventChangesDate() async throws {
		// Given: event with current date
		let medication = createTestMedication()
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event with new date
		let newDate = Date().addingTimeInterval(-3600) // 1 hour ago
		await viewModel.updateEvent(event, newDate: newDate, newAmount: 2.0, newUnit: .tablet)

		// Then: event date should be updated
		let updatedEvent = dataStore.events.first { $0.id == event.id }
		#expect(updatedEvent?.date.timeIntervalSince1970 == newDate.timeIntervalSince1970, "Event date should be updated to new date")
	}

	// MARK: - Unit Change Tests

	@Test("Update event changes unit correctly")
	func updateEventChangesUnit() async throws {
		// Given: event with tablet unit
		let medication = createTestMedication()
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event to use milliliter unit
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .milliliter)

		// Then: event unit should be updated
		let updatedEvent = dataStore.events.first { $0.id == event.id }
		#expect(updatedEvent?.dose?.unit == .milliliter, "Event unit should be updated to milliliter")
	}

	// MARK: - Edge Case Tests

	@Test("Update event with nil medication quantity doesn't crash")
	func updateEventWithNilQuantity() async throws {
		// Given: medication with nil quantity
		var medication = createTestMedication()
		medication.quantity = nil
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event dose
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 3.0, newUnit: .tablet)

		// Then: should not crash and medication quantity should remain nil
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == nil, "Quantity should remain nil when original quantity is nil")
	}

	@Test("Update event with large dose increase")
	func updateEventLargeDoseIncrease() async throws {
		// Given: medication with quantity 100, event with dose 1
		let medication = createTestMedication(quantity: 100.0)
		let event = createTestEvent(medication: medication, amount: 1.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event dose from 1 to 50
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 50.0, newUnit: .tablet)

		// Then: medication quantity should decrease by 49 (100 - 49 = 51)
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == 51.0, "Quantity should decrease from 100 to 51 when dose increases from 1 to 50")
	}

	@Test("Update event with fractional dose amounts")
	func updateEventFractionalDoses() async throws {
		// Given: medication with quantity 10.5, event with dose 0.5
		let medication = createTestMedication(quantity: 10.5)
		let event = createTestEvent(medication: medication, amount: 0.5, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

		// When: update event dose from 0.5 to 1.5
		await viewModel.updateEvent(event, newDate: event.date, newAmount: 1.5, newUnit: .tablet)

		// Then: medication quantity should decrease by 1.0 (10.5 - 1.0 = 9.5)
		let updatedMedication = dataStore.medications.first { $0.id == medication.id }
		#expect(updatedMedication?.quantity == 9.5, "Quantity should decrease from 10.5 to 9.5 when dose increases from 0.5 to 1.5")
	}

	@Test("Updating a history note preserves structured reflection data")
	func updateEventNotePreservesStructuredReflectionData() async throws {
		clearStoredSelection()
		let medication = createTestMedication(quantity: 10.0)
		var event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)
		event.note = try DoseReflectionCodec.encode(
			DoseReflection(
				reason: "Headache",
				symptomSeverityBefore: 6,
				symptomSeverityAfter: 2,
				effectiveness: 4,
				sideEffects: ["Sleepy"],
				note: "Original note"
			)
		)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-StructuredNote")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore)
		let updatedNote = try DoseReflectionCodec.updatingNote(in: event.note, with: "Updated note")
		var updatedEvent = event
		updatedEvent.note = updatedNote

		await viewModel.updateEventNote(updatedEvent)

		let storedEvent = try #require(dataStore.events.first { $0.id == event.id })
		let reflection = try #require(DoseReflectionCodec.reflection(from: storedEvent.note))
		#expect(reflection.reason == "Headache")
		#expect(reflection.effectiveness == 4)
		#expect(reflection.note == "Updated note")
	}

	@Test("Bulk deletion restores every dose for the same medication")
	func bulkDeleteRestoresEveryDoseForOneMedication() async throws {
		let medication = createTestMedication(quantity: 10)
		let today = Calendar.current.startOfDay(for: .now)
		let dataStore = DataStore(testIdentifier: "History-BulkSameMedication-\(UUID().uuidString)")
		try await dataStore.addMedication(medication)
		for (index, amount) in [2.0, 3.0].enumerated() {
			try await dataStore.addEvent(ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: amount, unit: .tablet),
				date: today.addingTimeInterval(Double(index + 1) * 60)
			))
		}
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		let deleted = await viewModel.deleteEvents(at: IndexSet([0, 1]), in: today)

		#expect(deleted)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first(where: { $0.id == medication.id })?.quantity == 15)
		#expect(viewModel.mutationError == nil)
	}

	@Test("Editing an event and its note keeps one record with the original identity")
	func eventUpdatesReplaceTheSameIDWithoutDuplicates() async throws {
		let medication = createTestMedication(quantity: 10)
		let event = createTestEvent(medication: medication, amount: 2, unit: .tablet)
		let dataStore = DataStore(testIdentifier: "History-UpsertIdentity-\(UUID().uuidString)")
		try await dataStore.addMedication(medication)
		try await dataStore.addEvent(event)
		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)
		let newDate = event.date.addingTimeInterval(-60)

		#expect(await viewModel.updateEvent(event, newDate: newDate, newAmount: 3, newUnit: .tablet))
		// A retained editor snapshot must compare against the dose currently stored, not its old value.
		#expect(await viewModel.updateEvent(event, newDate: newDate, newAmount: 4, newUnit: .tablet))
		var updatedEvent = try #require(dataStore.events.first(where: { $0.id == event.id }))
		updatedEvent.note = "Updated note"
		#expect(await viewModel.updateEventNote(updatedEvent))

		let storedEvent = try #require(dataStore.events.first)
		#expect(dataStore.events.count == 1)
		#expect(storedEvent.id == event.id)
		#expect(storedEvent.date == newDate)
		#expect(storedEvent.dose?.amount == 4)
		#expect(storedEvent.note == "Updated note")
		#expect(dataStore.medications.first(where: { $0.id == medication.id })?.quantity == 8)
	}

	@Test("Deleting an event restores medication quantity")
	func deleteEventRestoresMedicationQuantity() async throws {
		clearStoredSelection()
		let medication = createTestMedication(quantity: 5.0)
		let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-DeleteEvent")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(event)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		await viewModel.deleteEvent(event)

		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first?.quantity == 7.0)
	}

	@Test("Deleting events by offset restores only the targeted event quantities")
	func deleteEventsByOffsetRestoresTargetedQuantities() async throws {
		clearStoredSelection()
		let medication = createTestMedication(quantity: 10.0)
		let today = Calendar.current.startOfDay(for: .now)
		let firstEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 1.0, unit: .tablet),
			date: today.addingTimeInterval(3600)
		)
		let secondEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 2.0, unit: .tablet),
			date: today.addingTimeInterval(7200)
		)

		let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-DeleteOffsets")
		try? await dataStore.addMedication(medication)
		try? await dataStore.addEvent(firstEvent)
		try? await dataStore.addEvent(secondEvent)

		let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

		await viewModel.deleteEvents(at: IndexSet(integer: 0), in: today)

		#expect(dataStore.events.count == 1)
		#expect(dataStore.medications.first?.quantity == 12.0)
	}
	@Test("All History chooser excludes archived medications and keeps list order")
	func allHistoryLogChoices() {
		let previousSelection = UserDefaults.standard.object(forKey: UserDefaultsKeys.historySelectedMedicationID)
		defer { UserDefaults.standard.set(previousSelection, forKey: UserDefaultsKeys.historySelectedMedicationID) }
		let store = DataStore(testIdentifier: "History-Chooser-\(UUID().uuidString)")
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: "all", notificationCenter: NotificationCenter())
		let first = ANMedicationConcept(clinicalName: "Synthetic Z")
		let second = ANMedicationConcept(clinicalName: "Synthetic A")
		var archived = ANMedicationConcept(clinicalName: "Synthetic archived")
		archived.isArchived = true
		model.medications = [first, archived, second]
		#expect(model.isShowingAllMedications)
		#expect(model.logDosePickerMedications.map(\.id) == [first.id, second.id])
		model.medications = [archived]
		#expect(model.logDosePickerMedications.isEmpty)
	}

}

// MedicationTrendsViewModelTests.swift
// Comprehensive unit tests for MedicationTrendsViewModel

import ANModelKit
@testable import AsNeeded
import Foundation
import Combine
import Testing

@MainActor
@Suite("MedicationTrendsViewModel Tests", .tags(.medication, .viewModel, .trends, .unit))
struct MedicationTrendsViewModelTests {
    // MARK: - Test Helpers

    private func clearStoredSelection() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.trendsSelectedMedicationID)
    }

    private func createTestMedication(
        name: String = "TestMed",
        quantity: Double = 100.0,
        initialQuantity: Double? = nil,
        lastRefill: Date? = nil,
        nextRefill: Date? = nil,
        unit: ANUnitConcept = .tablet
    ) -> ANMedicationConcept {
        ANMedicationConcept(
            clinicalName: name,
            nickname: nil,
            quantity: quantity,
            initialQuantity: initialQuantity,
            lastRefillDate: lastRefill,
            nextRefillDate: nextRefill,
            prescribedUnit: unit,
            prescribedDoseAmount: 2.0
        )
    }

    private func createTestEvent(
        medication: ANMedicationConcept,
        date: Date,
        amount: Double,
        unit: ANUnitConcept
    ) -> ANEventConcept {
        let dose = ANDoseConcept(amount: amount, unit: unit)
        return ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: date
        )
    }

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with empty medication list")
    func initializationEmpty() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-Empty")
        let viewModel = MedicationTrendsViewModel(dataStore: dataStore)

        #expect(viewModel.medications.isEmpty)
        #expect(viewModel.selectedMedicationID == nil)
    }

    @Test("ViewModel initializes with medications and selects first")
    func initializationWithMedications() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-Init")
        let medication = createTestMedication(name: "Aspirin")
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore)

        #expect(viewModel.medications.count == 1)
        #expect(viewModel.selectedMedicationID == medication.id)
    }

    @Test("ViewModel initializes with specific medication ID")
    func initializationWithSpecificID() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-SpecificID")
        let med1 = createTestMedication(name: "Med1")
        let med2 = createTestMedication(name: "Med2")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: med2.id)

        #expect(viewModel.selectedMedicationID == med2.id)
        #expect(viewModel.selectedMedication?.clinicalName == "Med2")
    }

    // MARK: - Selection Management Tests

    @Test("EnsureValidSelection selects first medication when none selected")
    func ensureValidSelectionNoneSelected() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-SelectFirst")
        let medication = createTestMedication(name: "FirstMed")
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore)
        viewModel.selectedMedicationIDString = "" // Clear selection

        viewModel.ensureValidSelection()

        #expect(viewModel.selectedMedicationID == medication.id)
    }

    @Test("EnsureValidSelection keeps valid selection")
    func ensureValidSelectionKeepsValid() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-KeepValid")
        let med1 = createTestMedication(name: "Med1")
        let med2 = createTestMedication(name: "Med2")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: med2.id)

        viewModel.ensureValidSelection()

        #expect(viewModel.selectedMedicationID == med2.id)
    }

    @Test("EnsureValidSelection changes invalid selection to first")
    func ensureValidSelectionInvalidToFirst() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-InvalidToFirst")
        let medication = createTestMedication(name: "ValidMed")
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore)
        viewModel.selectedMedicationIDString = UUID().uuidString // Invalid ID

        viewModel.ensureValidSelection()

        #expect(viewModel.selectedMedicationID == medication.id)
    }

    // MARK: - Event Filtering Tests

    @Test("Events filtered by medication ID")
    func eventsFilteredByMedicationID() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-EventFilter")
        let med1 = createTestMedication(name: "Med1")
        let med2 = createTestMedication(name: "Med2")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        let event1 = createTestEvent(medication: med1, date: Date(), amount: 1.0, unit: .tablet)
        let event2 = createTestEvent(medication: med2, date: Date(), amount: 2.0, unit: .tablet)
        try await dataStore.addEvent(event1)
        try await dataStore.addEvent(event2)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: med1.id)

        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.medication?.id == med1.id)
    }

    @Test("Events filtered by doseTaken type only")
    func eventsFilteredByDoseTakenType() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-DoseTakenOnly")
        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let doseTakenEvent = createTestEvent(medication: medication, date: Date(), amount: 1.0, unit: .tablet)
        // Create a non-doseTaken event to verify it's filtered out
        let reconcileEvent = ANEventConcept(
            eventType: .reconcile,
            medication: medication,
            dose: nil,
            date: Date().addingTimeInterval(1)
        )
        try await dataStore.addEvent(doseTakenEvent)
        try await dataStore.addEvent(reconcileEvent)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        // Only doseTaken events should be included
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.eventType == .doseTaken)
    }

    @Test("Events sorted by date ascending")
    func eventsSortedByDate() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-EventSort")
        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let date1 = Date().addingTimeInterval(-3600) // 1 hour ago
        let date2 = Date().addingTimeInterval(-7200) // 2 hours ago
        let date3 = Date() // Now

        let event1 = createTestEvent(medication: medication, date: date1, amount: 1.0, unit: .tablet)
        let event2 = createTestEvent(medication: medication, date: date2, amount: 1.0, unit: .tablet)
        let event3 = createTestEvent(medication: medication, date: date3, amount: 1.0, unit: .tablet)

        try await dataStore.addEvent(event1)
        try await dataStore.addEvent(event2)
        try await dataStore.addEvent(event3)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let events = viewModel.events as? [ANEventConcept], events.count == 3 else {
            Issue.record("Expected 3 events")
            return
        }

        #expect(events[0].date < events[1].date)
        #expect(events[1].date < events[2].date)
    }

    // MARK: - Preferred Unit Tests

    @Test("PreferredUnit returns prescribed unit when available")
    func preferredUnitFromPrescribed() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-PreferredPrescribed")
        let medication = createTestMedication(name: "TestMed", unit: .milligram)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.preferredUnit == .milligram)
    }

    @Test("PreferredUnit returns event unit when prescribed unit unavailable")
    func preferredUnitFromEvent() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-PreferredEvent")
        var medication = createTestMedication(name: "TestMed")
        medication.prescribedUnit = nil
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication, date: Date(), amount: 5.0, unit: .milliliter)
        try await dataStore.addEvent(event)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.preferredUnit == .milliliter)
    }

    @Test("PreferredUnit returns nil when no units available")
    func preferredUnitNil() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-PreferredNil")
        var medication = createTestMedication(name: "TestMed")
        medication.prescribedUnit = nil
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.preferredUnit == nil)
    }

    // MARK: - Daily Totals Tests

    @Test("DailyTotals calculates correctly for single day")
    func dailyTotalsSingleDay() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DailySingle")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let today = try #require(Calendar.current.date(byAdding: .hour, value: -12, to: Calendar.current.startOfDay(for: Date())))
        let event1 = createTestEvent(medication: medication, date: today, amount: 2.0, unit: .tablet)
        let event2 = createTestEvent(medication: medication, date: today.addingTimeInterval(3600), amount: 3.0, unit: .tablet)
        try await dataStore.addEvent(event1)
        try await dataStore.addEvent(event2)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let dailyTotals = viewModel.dailyTotals(last: 1)

        guard let total = dailyTotals.first else {
            Issue.record("Expected daily total")
            return
        }

        #expect(total.total == 5.0)
    }

    @Test("DailyTotals includes zero days")
    func dailyTotalsIncludesZeroDays() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DailyZero")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let dailyTotals = viewModel.dailyTotals(last: 7)

        #expect(dailyTotals.count == 7)
        #expect(dailyTotals.allSatisfy { $0.total == 0.0 })
    }

    @Test("Pattern summary highlights clustered evening usage")
    func patternSummaryHighlightsClusteredEveningUsage() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-PatternSummary")
        let medication = createTestMedication(name: "PatternMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let today = Calendar.current.startOfDay(for: Date())
        for dayOffset in 0 ..< 4 {
            let baseDay = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let eventDate = Calendar.current.date(byAdding: .hour, value: 21, to: baseDay) ?? baseDay
            try await dataStore.addEvent(createTestEvent(medication: medication, date: eventDate, amount: 2.0, unit: .tablet))
        }

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.patternSummary.contains("evening"))
    }

    @Test("DailyTotals calculates correct 14-day window")
    func dailyTotals14Days() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-Daily14")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())))

        for daysAgo in 0 ..< 14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let event = createTestEvent(medication: medication, date: date, amount: 1.0, unit: .tablet)
            try await dataStore.addEvent(event)
        }

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let dailyTotals = viewModel.dailyTotals(last: 14)

        #expect(dailyTotals.count == 14)
        #expect(dailyTotals.allSatisfy { $0.total == 1.0 })
    }

    @Test("DailyTotals only counts matching units")
    func dailyTotalsMatchingUnitsOnly() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DailyUnits")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let today = try #require(Calendar.current.date(byAdding: .hour, value: -12, to: Calendar.current.startOfDay(for: Date())))
        let tabletEvent = createTestEvent(medication: medication, date: today, amount: 2.0, unit: .tablet)
        let mlEvent = createTestEvent(medication: medication, date: today, amount: 5.0, unit: .milliliter)
        try await dataStore.addEvent(tabletEvent)
        try await dataStore.addEvent(mlEvent)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let dailyTotals = viewModel.dailyTotals(last: 1)

        guard let total = dailyTotals.first else {
            Issue.record("Expected daily total")
            return
        }

        #expect(total.total == 2.0) // Only tablet counted
    }

	@Test("Trends cache follows selection and preferred medication unit changes")
	func derivedCacheInvalidatesForSelectionAndMedicationUnit() async throws {
		let store = DataStore(testIdentifier: "Trends-Cache-\(UUID().uuidString)")
		let first = createTestMedication(name: "First", unit: .tablet)
		var second = createTestMedication(name: "Second", unit: .tablet)
		try await store.addMedication(first)
		try await store.addMedication(second)
		let today = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)))
		try await store.addEvent(createTestEvent(medication: first, date: today, amount: 2, unit: .tablet))
		try await store.addEvent(createTestEvent(medication: second, date: today, amount: 3, unit: .tablet))
		try await store.addEvent(createTestEvent(medication: second, date: today, amount: 5, unit: .milliliter))
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: first.id)
		#expect(model.dailyTotals(last: 1).first?.total == 2)
		model.selectedMedicationID = second.id
		#expect(model.events.count == 2)
		#expect(model.dailyTotals(last: 1).first?.total == 3)
		second.prescribedUnit = .milliliter
		model.medications = [first, second]
		#expect(model.dailyTotals(last: 1).first?.total == 5)
		#expect(model.calendarHeatmapData(last: 1).first?.total == 5)
		#expect(model.dailyTotals(last: 0).isEmpty)
	}

	@Test("Trends invalidates cached totals for event-only edits", .timeLimit(.minutes(1)))
	func trendsObservesEventOnlyEdit() async throws {
		let store = DataStore(testIdentifier: "Trends-ObservedEdit-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		var event = createTestEvent(medication: medication, date: try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))), amount: 2, unit: .tablet)
		try await store.addEvent(event)
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: medication.id)
		#expect(model.dailyTotals(last: 1).first?.total == 2)
		let updates = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
		let subscription = model.objectWillChange.sink { updates.continuation.yield(()) }
		let observation = Task { @MainActor in
			for await _ in updates.stream {
				if model.dailyTotals(last: 1).first?.total == 0 { return }
			}
		}
		defer {
			observation.cancel()
			subscription.cancel()
			updates.continuation.finish()
		}
		event.date = Calendar.current.date(byAdding: .day, value: -2, to: event.date) ?? event.date
		try await store.updateEvent(event)
		await observation.value
		#expect(model.dailyTotals(last: 1).first?.total == 0)
		#expect(model.calendarHeatmapData(last: 3).first?.total == 2)
	}

	@Test("Trends receives cold loaded events and retains the requested medication", .timeLimit(.minutes(1)))
	func trendsObservesColdStoreLoad() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Trends-ColdLoad-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }
		let medication = createTestMedication()
		let writer = DataStore(storageDirectory: directory)
		try await writer.addMedication(medication)
		let event = createTestEvent(medication: medication, date: try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))), amount: 2, unit: .tablet)
		try await writer.addEvent(event)
		let reader = DataStore(storageDirectory: directory)
		let model = MedicationTrendsViewModel(dataStore: reader, selectedMedicationID: medication.id)
		let updates = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
		let subscription = model.objectWillChange.sink { updates.continuation.yield(()) }
		defer {
			subscription.cancel()
			updates.continuation.finish()
		}
		if model.events.isEmpty {
			for await _ in updates.stream {
				if model.events.contains(where: { $0.id == event.id }) { break }
			}
		}
		#expect(model.selectedMedicationID == medication.id)
		#expect(model.dailyTotals(last: 1).first?.total == 2)
	}

	@Test("Trends advances its completed-day window after a clock refresh")
	func clockRefreshAdvancesDailyWindow() async throws {
		let store = DataStore(testIdentifier: "Trends-Clock-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
		var referenceDate = day
		try await store.addEvent(createTestEvent(medication: medication, date: day, amount: 2, unit: .tablet))
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: medication.id, notificationCenter: NotificationCenter(), now: { referenceDate })
		#expect(model.dailyTotals(last: 1).first?.total == 0)
		var refreshes = 0
		let subscription = model.objectWillChange.sink { refreshes += 1 }
		defer { subscription.cancel() }
		referenceDate = try #require(Calendar.current.date(byAdding: .day, value: 1, to: day))
		model.refreshForClockChange()
		#expect(refreshes == 1)
		#expect(model.dailyTotals(last: 1).first?.day == day)
		#expect(model.dailyTotals(last: 1).first?.total == 2)
	}

	@Test("Trends foreground refresh loads doses saved by another store")
	func foregroundRefreshLoadsExternalDose() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Trends-Foreground-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }
		let reader = DataStore(storageDirectory: directory)
		let medication = createTestMedication()
		try await reader.addMedication(medication)
		let model = MedicationTrendsViewModel(dataStore: reader, selectedMedicationID: medication.id, notificationCenter: NotificationCenter())
		await model.refreshAfterForeground()
		#expect(model.events.isEmpty)
		let writer = DataStore(storageDirectory: directory)
		let event = createTestEvent(medication: medication, date: try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))), amount: 2, unit: .tablet)
		try await writer.recordDose(event)
		await model.refreshAfterForeground()
		#expect(model.events.map(\.id) == [event.id])
		#expect(model.dailyTotals(last: 1).first?.total == 2)
	}

	@Test("90 complete days include exact bounds and respect daylight saving", arguments: [
		("2026-03-09T12:00:00Z", 23),
		("2026-11-02T12:00:00Z", 25)
	])
	func completeDayBoundariesAcrossDaylightSaving(reference: String, yesterdayHours: Int) async throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
		let now = try #require(ISO8601DateFormatter().date(from: reference))
		let today = calendar.startOfDay(for: now)
		let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
		let oldest = try #require(calendar.date(byAdding: .day, value: -90, to: today))
		let store = DataStore(testIdentifier: "Trends-Bounds-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		for (date, amount) in [(oldest.addingTimeInterval(-1), 100.0), (oldest, 2.0), (today.addingTimeInterval(-1), 3.0), (today, 100.0), (today.addingTimeInterval(86_400), 100.0)] {
			try await store.addEvent(createTestEvent(medication: medication, date: date, amount: amount, unit: .tablet))
		}
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: medication.id, calendar: { calendar }, now: { now })
		let totals = model.dailyTotals(last: 90)
		#expect(totals.count == 90)
		#expect(totals.first?.day == oldest)
		#expect(totals.last?.day == yesterday)
		#expect(totals.map(\.total).reduce(0, +) == 5)
		#expect(model.averagePerDay(window: 90) == 5.0 / 90.0)
		#expect(model.calendarHeatmapData(last: 90).map(\.date) == totals.map(\.day))
		#expect(today.timeIntervalSince(yesterday) == Double(yesterdayHours * 3_600))
	}

	@Test("Timezone refresh rebuckets cached totals and changes the completed-day cutoff")
	func timezoneRefreshRebucketsCompletedDays() async throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
		let now = try #require(ISO8601DateFormatter().date(from: "2026-10-28T01:00:00Z"))
		let eventDate = try #require(ISO8601DateFormatter().date(from: "2026-10-27T23:30:00Z"))
		let store = DataStore(testIdentifier: "Trends-Zone-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		try await store.addEvent(createTestEvent(medication: medication, date: eventDate, amount: 4, unit: .tablet))
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: medication.id, calendar: { calendar }, now: { now })
		#expect(model.dailyTotals(last: 1).first?.total == 4)
		calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
		model.refreshForClockChange()
		#expect(model.dailyTotals(last: 1).first?.total == 0)
		#expect(model.calendarHeatmapData(last: 1).first?.total == 0)
		#expect(model.patternSummary.contains("after the day is complete"))
	}

	@Test("Weekly comparison and heatmap scale ignore today's partial and future doses")
	func completedWeekComparisonIgnoresPartialDay() async throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
		let now = try #require(ISO8601DateFormatter().date(from: "2026-10-28T12:00:00Z"))
		let store = DataStore(testIdentifier: "Trends-Comparison-\(UUID().uuidString)")
		let medication = createTestMedication()
		try await store.addMedication(medication)
		for daysAgo in 1 ... 14 {
			let date = try #require(calendar.date(byAdding: .day, value: -daysAgo, to: now))
			try await store.addEvent(createTestEvent(medication: medication, date: date, amount: daysAgo <= 7 ? 1 : 3, unit: .tablet))
		}
		for daysAhead in 0 ... 1 {
			let date = try #require(calendar.date(byAdding: .day, value: daysAhead, to: now))
			try await store.addEvent(createTestEvent(medication: medication, date: date, amount: 1_000, unit: .tablet))
		}
		let model = MedicationTrendsViewModel(dataStore: store, selectedMedicationID: medication.id, calendar: { calendar }, now: { now })
		#expect(model.averagePerDay(window: 7) == 1)
		#expect(model.patternSummary.contains("lighter than the week before"))
		#expect(model.calendarHeatmapData(last: 14).map(\.intensity).max() == 1)
		#expect(model.dailyTotals(last: -1).isEmpty)
	}

    // MARK: - Average Per Day Tests

    @Test("AveragePerDay calculates correctly")
    func testAveragePerDay() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-AvgPerDay")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())))

        // Add events: Day 0: 3 tablets, Day -1: 6 tablets, Day -2: 3 tablets
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)
        else {
            Issue.record("Failed to create dates")
            return
        }

        try await dataStore.addEvent(createTestEvent(medication: medication, date: today, amount: 3.0, unit: .tablet))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: yesterday, amount: 6.0, unit: .tablet))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: twoDaysAgo, amount: 3.0, unit: .tablet))

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let average = viewModel.averagePerDay(window: 3)

        #expect(average == 4.0) // (3 + 6 + 3) / 3 = 4
    }

    @Test("AveragePerDay returns zero when no events")
    func averagePerDayNoEvents() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-AvgNoEvents")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let average = viewModel.averagePerDay(window: 7)

        #expect(average == 0.0)
    }

    @Test("AveragePerDay handles partial window")
    func averagePerDayPartialWindow() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-AvgPartial")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let today = try #require(Calendar.current.date(byAdding: .hour, value: -12, to: Calendar.current.startOfDay(for: Date())))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: today, amount: 7.0, unit: .tablet))

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let average = viewModel.averagePerDay(window: 7)

        #expect(average == 1.0) // 7 tablets / 7 days = 1
    }

    // MARK: - Days Until Refill Tests

    @Test("DaysUntilRefill calculates correctly")
    func testDaysUntilRefill() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DaysRefill")
        let calendar = Calendar.current
        let nextRefill = calendar.date(byAdding: .day, value: 10, to: Date())
        let medication = createTestMedication(name: "TestMed", nextRefill: nextRefill)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let days = viewModel.daysUntilRefill else {
            Issue.record("Expected days until refill")
            return
        }

        #expect(days == 10)
    }

    @Test("DaysUntilRefill returns nil when no refill date")
    func daysUntilRefillNil() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DaysRefillNil")
        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.daysUntilRefill == nil)
    }

    @Test("DaysUntilRefill handles today as refill date")
    func daysUntilRefillToday() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-DaysRefillToday")
        let medication = createTestMedication(name: "TestMed", nextRefill: Date())
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let days = viewModel.daysUntilRefill else {
            Issue.record("Expected days until refill")
            return
        }

        #expect(days == 0)
    }

    // MARK: - Estimated Days Remaining Tests

    @Test("EstimatedDaysRemaining calculates correctly")
    func testEstimatedDaysRemaining() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-EstDays")
        let medication = createTestMedication(name: "TestMed", quantity: 70.0, unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add 10 tablets per day for 7 days (avg: 10 per day)
        for daysAgo in 0 ..< 7 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            try await dataStore.addEvent(createTestEvent(medication: medication, date: date, amount: 10.0, unit: .tablet))
        }

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let daysRemaining = viewModel.estimatedDaysRemaining else {
            Issue.record("Expected estimated days remaining")
            return
        }

        #expect(daysRemaining == 7) // 70 tablets / 10 per day = 7 days
    }

    @Test("EstimatedDaysRemaining returns nil when quantity is zero")
    func estimatedDaysRemainingZeroQuantity() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-EstDaysZeroQty")
        let medication = createTestMedication(name: "TestMed", quantity: 0.0)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.estimatedDaysRemaining == nil)
    }

    @Test("EstimatedDaysRemaining returns nil when average is zero")
    func estimatedDaysRemainingZeroAverage() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-EstDaysZeroAvg")
        let medication = createTestMedication(name: "TestMed", quantity: 50.0)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.estimatedDaysRemaining == nil)
    }

    // MARK: - Usage Percentage Tests

    @Test("UsagePercentage calculates correctly")
    func testUsagePercentage() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-UsagePct")
        let medication = createTestMedication(
            name: "TestMed",
            quantity: 60.0,
            initialQuantity: 100.0
        )
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let percentage = viewModel.usagePercentage else {
            Issue.record("Expected usage percentage")
            return
        }

        #expect(percentage == 40.0) // (100 - 60) / 100 * 100 = 40%
    }

    @Test("UsagePercentage returns nil when initial quantity missing")
    func usagePercentageNoInitial() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-UsagePctNoInit")
        let medication = createTestMedication(name: "TestMed", quantity: 50.0)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.usagePercentage == nil)
    }

    @Test("UsagePercentage capped at 100 percent")
    func usagePercentageCapped() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-UsagePctCap")
        let medication = createTestMedication(
            name: "TestMed",
            quantity: -10.0, // Over-used
            initialQuantity: 50.0
        )
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        guard let percentage = viewModel.usagePercentage else {
            Issue.record("Expected usage percentage")
            return
        }

        #expect(percentage == 100.0) // Capped at 100%
    }

    // MARK: - Refill Cycle Status Tests

    @Test("RefillCycleStatus is onTrack when usage matches time")
    func refillCycleStatusOnTrack() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-RefillOnTrack")
        let calendar = Calendar.current

        let lastRefill = calendar.date(byAdding: .day, value: -15, to: Date())
        let nextRefill = calendar.date(byAdding: .day, value: 15, to: Date())

        let medication = createTestMedication(
            name: "TestMed",
            quantity: 50.0,
            initialQuantity: 100.0,
            lastRefill: lastRefill,
            nextRefill: nextRefill
        )
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.refillCycleStatus == .onTrack) // 50% time, 50% used (within 10% tolerance)
    }

    @Test("RefillCycleStatus is ahead when using slower")
    func refillCycleStatusAhead() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-RefillAhead")
        let calendar = Calendar.current

        let lastRefill = calendar.date(byAdding: .day, value: -20, to: Date())
        let nextRefill = calendar.date(byAdding: .day, value: 10, to: Date())

        let medication = createTestMedication(
            name: "TestMed",
            quantity: 80.0, // Only used 20 out of 100
            initialQuantity: 100.0,
            lastRefill: lastRefill,
            nextRefill: nextRefill
        )
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.refillCycleStatus == .ahead) // 67% time elapsed, 20% used
    }

    @Test("RefillCycleStatus is behind when using faster")
    func refillCycleStatusBehind() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-RefillBehind")
        let calendar = Calendar.current

        let lastRefill = calendar.date(byAdding: .day, value: -10, to: Date())
        let nextRefill = calendar.date(byAdding: .day, value: 20, to: Date())

        let medication = createTestMedication(
            name: "TestMed",
            quantity: 20.0, // Used 80 out of 100
            initialQuantity: 100.0,
            lastRefill: lastRefill,
            nextRefill: nextRefill
        )
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.refillCycleStatus == .behind) // 33% time elapsed, 80% used
    }

    @Test("RefillCycleStatus is unknown when dates missing")
    func refillCycleStatusUnknown() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-RefillUnknown")
        let medication = createTestMedication(name: "TestMed", quantity: 50.0, initialQuantity: 100.0)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)

        #expect(viewModel.refillCycleStatus == .unknown)
    }

    // MARK: - Calendar Heatmap Tests

    @Test("CalendarHeatmapData returns correct number of days")
    func calendarHeatmapDataCount() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-HeatmapCount")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let heatmapData = viewModel.calendarHeatmapData(last: 30)

        #expect(heatmapData.count == 30)
    }

    @Test("CalendarHeatmapData includes zero-usage days")
    func calendarHeatmapDataZeroDays() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-HeatmapZero")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let heatmapData = viewModel.calendarHeatmapData(last: 7)

        #expect(heatmapData.count == 7)
        #expect(heatmapData.allSatisfy { $0.total == 0.0 && $0.intensity == 0.0 })
    }

    @Test("CalendarHeatmapData calculates intensity correctly")
    func calendarHeatmapDataIntensity() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-HeatmapIntensity")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())))

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            Issue.record("Failed to create date")
            return
        }

        // Today: 10 tablets (max), Yesterday: 5 tablets (half intensity)
        try await dataStore.addEvent(createTestEvent(medication: medication, date: today, amount: 10.0, unit: .tablet))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: yesterday, amount: 5.0, unit: .tablet))

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let heatmapData = viewModel.calendarHeatmapData(last: 2)

        guard heatmapData.count == 2 else {
            Issue.record("Expected 2 heatmap entries")
            return
        }

        let yesterdayData = heatmapData[0]
        let todayData = heatmapData[1]

        #expect(yesterdayData.intensity == 0.5) // 5 / 10 = 0.5
        #expect(todayData.intensity == 1.0) // 10 / 10 = 1.0
    }

    @Test("CalendarHeatmapData aggregates multiple events per day")
    func calendarHeatmapDataAggregation() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-HeatmapAggregate")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let today = try #require(Calendar.current.date(byAdding: .hour, value: -12, to: Calendar.current.startOfDay(for: Date())))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: today, amount: 2.0, unit: .tablet))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: today.addingTimeInterval(3600), amount: 3.0, unit: .tablet))
        try await dataStore.addEvent(createTestEvent(medication: medication, date: today.addingTimeInterval(7200), amount: 5.0, unit: .tablet))

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let heatmapData = viewModel.calendarHeatmapData(last: 1)

        guard let dayData = heatmapData.first else {
            Issue.record("Expected heatmap data")
            return
        }

        #expect(dayData.total == 10.0) // 2 + 3 + 5
    }

    @Test("Next eligible dose date reflects saved minimum interval guidance")
    func nextEligibleDoseDateUsesSavedGuidance() async throws {
        clearStoredSelection()
        let defaults = UserDefaults(suiteName: "TrendsVM-Safety-\(UUID().uuidString)") ?? .standard
        let safetyStore = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
        let dataStore = DataStore(testIdentifier: "TrendsVM-NextEligible")
        let medication = createTestMedication(name: "Naproxen")
        try await dataStore.addMedication(medication)

        let recentEvent = createTestEvent(
            medication: medication,
            date: Date().addingTimeInterval(-3600),
            amount: 1,
            unit: .tablet
        )
        try await dataStore.addEvent(recentEvent)
        safetyStore.save(.init(minimumHoursBetweenDoses: 4), for: medication.id)

        let viewModel = MedicationTrendsViewModel(
            dataStore: dataStore,
            selectedMedicationID: medication.id,
            safetyProfileStore: safetyStore
        )

        let nextEligibleDate = try #require(viewModel.nextEligibleDoseDate)
        #expect(nextEligibleDate > Date())
    }

}

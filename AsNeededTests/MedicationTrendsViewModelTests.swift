// MedicationTrendsViewModelTests.swift
// Comprehensive unit tests for MedicationTrendsViewModel

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("MedicationTrendsViewModel Tests", .tags(.medication, .viewModel, .trends, .unit))
struct MedicationTrendsViewModelTests {
    // MARK: - Test Helpers

    private struct MockGenerator: TrendsQuestionGenerating {
        let response: TrendsQuestionAnswer

        func answer(prompt: String) async throws -> TrendsQuestionAnswer {
            response
        }
    }

    private struct ThrowingGenerator: TrendsQuestionGenerating {
        let error: any Error

        func answer(prompt: String) async throws -> TrendsQuestionAnswer {
            throw error
        }
    }

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

        let today = Date()
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

    @Test("Question context includes refill and quantity summaries")
    func questionContextIncludesRefillAndQuantitySummaries() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-QuestionContext")
        let medication = createTestMedication(name: "ContextMed", quantity: 18, initialQuantity: 30, nextRefill: Date().addingTimeInterval(5 * 86_400), unit: .tablet)
        try await dataStore.addMedication(medication)
        try await dataStore.addEvent(createTestEvent(medication: medication, date: Date().addingTimeInterval(-3600), amount: 2, unit: .tablet))

        let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
        let context = viewModel.questionContext(windowDays: 14)

        #expect(context?.medicationName == "ContextMed")
        #expect(context?.quantitySummary.contains("18") == true)
        #expect(context?.refillSummary.isEmpty == false)
        #expect(context?.dailyTotals.isEmpty == false)
    }

    @Test("DailyTotals calculates correct 14-day window")
    func dailyTotals14Days() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-Daily14")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

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

        let today = Date()
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

    // MARK: - Average Per Day Tests

    @Test("AveragePerDay calculates correctly")
    func testAveragePerDay() async throws {
        let dataStore = DataStore(testIdentifier: "TrendsVM-AvgPerDay")
        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

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

        let today = Date()
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
        let today = calendar.startOfDay(for: Date())

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

        let today = Date()
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

    @Test("Question availability reflects injected question service state")
    func questionAvailabilityReflectsInjectedService() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-QuestionAvailability")
        let medication = createTestMedication(name: "Melatonin")
        try await dataStore.addMedication(medication)

        let service = MedicationTrendsQuestionService(
            isEnabledProvider: { false },
            isSupportedProvider: { true },
            generator: MockGenerator(
                response: TrendsQuestionAnswer(answer: "", highlights: [], limitations: [])
            )
        )

        let viewModel = MedicationTrendsViewModel(
            dataStore: dataStore,
            selectedMedicationID: medication.id,
            questionService: service
        )

        #expect(viewModel.questionAvailability == .disabled)
    }

    @Test("Example prompts are derived from the selected medication")
    func examplePromptsReflectSelectedMedication() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-ExamplePrompts")
        let medication = createTestMedication(name: "Ibuprofen")
        try await dataStore.addMedication(medication)

        let service = MedicationTrendsQuestionService(
            isEnabledProvider: { true },
            isSupportedProvider: { true },
            generator: MockGenerator(
                response: TrendsQuestionAnswer(answer: "", highlights: [], limitations: [])
            )
        )

        let viewModel = MedicationTrendsViewModel(
            dataStore: dataStore,
            selectedMedicationID: medication.id,
            questionService: service
        )

        #expect(viewModel.examplePrompts.count == 4)
        #expect(viewModel.examplePrompts.allSatisfy { $0.contains("Ibuprofen") })
    }

    @Test("Ask stores the generated answer for the selected medication")
    func askStoresGeneratedAnswer() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-AskSuccess")
        let medication = createTestMedication(name: "Ibuprofen")
        try await dataStore.addMedication(medication)
        try await dataStore.addEvent(
            createTestEvent(
                medication: medication,
                date: Date().addingTimeInterval(-1800),
                amount: 2,
                unit: .tablet
            )
        )

        let expectedAnswer = TrendsQuestionAnswer(
            answer: "Your logging is clustered in the evening.",
            highlights: ["Most entries are late in the day."],
            limitations: ["Recent data only."]
        )
        let service = MedicationTrendsQuestionService(
            isEnabledProvider: { true },
            isSupportedProvider: { true },
            generator: MockGenerator(response: expectedAnswer)
        )

        let viewModel = MedicationTrendsViewModel(
            dataStore: dataStore,
            selectedMedicationID: medication.id,
            questionService: service
        )

        await viewModel.ask(question: "When do I usually log this?", windowDays: 14)

        #expect(viewModel.latestQuestionAnswer == expectedAnswer)
        #expect(viewModel.questionErrorMessage == nil)
        #expect(viewModel.isAnsweringQuestion == false)
    }

    @Test("Ask surfaces service errors when private questions are disabled")
    func askSurfacesServiceErrors() async throws {
        clearStoredSelection()
        let dataStore = DataStore(testIdentifier: "TrendsVM-AskFailure")
        let medication = createTestMedication(name: "Ibuprofen")
        try await dataStore.addMedication(medication)

        let service = MedicationTrendsQuestionService(
            isEnabledProvider: { false },
            isSupportedProvider: { true },
            generator: ThrowingGenerator(error: TrendsQuestionServiceError.disabled)
        )

        let viewModel = MedicationTrendsViewModel(
            dataStore: dataStore,
            selectedMedicationID: medication.id,
            questionService: service
        )

        await viewModel.ask(question: "Do I log this consistently?", windowDays: 14)

        #expect(viewModel.latestQuestionAnswer == nil)
        #expect(viewModel.questionErrorMessage == "On-device questions are turned off in settings.")
        #expect(viewModel.isAnsweringQuestion == false)
    }
}

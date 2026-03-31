// MedicationTrendsViewModel.swift
// Computes usage trends and metrics for a selected medication.

import ANModelKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class MedicationTrendsViewModel: ObservableObject {
    @AppStorage(UserDefaultsKeys.trendsSelectedMedicationID) var selectedMedicationIDString: String = ""

    var selectedMedicationID: UUID? {
        get {
            selectedMedicationIDString.isEmpty ? nil : UUID(uuidString: selectedMedicationIDString)
        }
        set {
            selectedMedicationIDString = newValue?.uuidString ?? ""
        }
    }

    @Published var medications: [ANMedicationConcept] = []
    @Published var latestQuestionAnswer: TrendsQuestionAnswer?
    @Published var isAnsweringQuestion = false
    @Published var questionErrorMessage: String?

    private let dataStore: DataStore
    private let safetyProfileStore: MedicationSafetyProfileStore
    private let doseGuidanceService: MedicationDoseGuidanceService
    private let questionService: MedicationTrendsQuestionService
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    init(
        dataStore: DataStore = .shared,
        selectedMedicationID: UUID? = nil,
        safetyProfileStore: MedicationSafetyProfileStore = .shared,
        doseGuidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService(),
        questionService: MedicationTrendsQuestionService = MedicationTrendsQuestionService()
    ) {
        self.dataStore = dataStore
        self.safetyProfileStore = safetyProfileStore
        self.doseGuidanceService = doseGuidanceService
        self.questionService = questionService
        if let initialID = selectedMedicationID {
            self.selectedMedicationID = initialID
        }

        // Load initial data and observe changes
        loadData()
        observeStoreChanges()

        // Ensure we have a valid selection
        ensureValidSelection()
    }

    private func loadData() {
        medications = dataStore.medications
    }

    private func observeStoreChanges() {
        // Use Combine's Timer publisher instead of Foundation's Timer
        // This provides better integration with SwiftUI and proper cancellation
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newMedications = self.dataStore.medications
                if self.medications != newMedications {
                    self.medications = newMedications
                    self.ensureValidSelection()
                }
            }
            .store(in: &cancellables)
    }

    /// Ensures we always have a valid medication selected
    /// This prevents picker errors when selection is nil
    func ensureValidSelection() {
        // If no medications are loaded yet, wait
        guard !medications.isEmpty else { return }

        // If we have a selection and it's valid, keep it
        if let id = selectedMedicationID, medications.contains(where: { $0.id == id }) {
            return
        }

        // Otherwise, select the first medication
        selectedMedicationID = medications.first?.id
    }

    /// Legacy method for compatibility
    func validateSelectedMedication() {
        ensureValidSelection()
    }

    var selectedMedication: ANMedicationConcept? {
        guard let id = selectedMedicationID else { return nil }
        return medications.first { $0.id == id }
    }

    var safetyProfile: MedicationSafetyProfile {
        guard let medication = selectedMedication else {
            return .empty
        }

        return safetyProfileStore.profile(for: medication.id)
    }

    var events: [ANEventConcept] {
        guard let id = selectedMedicationID else { return [] }
        // Filter events ensuring medication IDs match exactly
        return dataStore.events
            .filter { event in
                // Only include events that have a medication with matching ID and are dose taken events
                guard let eventMedication = event.medication,
                      eventMedication.id == id,
                      event.eventType == .doseTaken
                else {
                    return false
                }
                return true
            }
            .sorted { $0.date < $1.date }
    }

    // Determine a preferred unit for aggregation
    var preferredUnit: ANUnitConcept? {
        selectedMedication?.prescribedUnit ?? events.compactMap { $0.dose?.unit }.first
    }

    var refillProjection: MedicationDoseGuidanceService.RefillProjection? {
        guard let medication = selectedMedication else {
            return nil
        }

        return doseGuidanceService.refillProjection(
            for: medication,
            events: events,
            profile: safetyProfile
        )
    }

    var nextEligibleDoseDate: Date? {
        guard let medication = selectedMedication else {
            return nil
        }

        return doseGuidanceService.nextEligibleDate(
            for: medication,
            events: events,
            profile: safetyProfile
        )
    }

    var questionAvailability: TrendsQuestionAvailability {
        questionService.availability
    }

    var examplePrompts: [String] {
        guard let medication = selectedMedication else {
            return []
        }

        return questionService.examplePrompts(for: medication)
    }

    // Daily totals for the last N days (default 14)
    func dailyTotals(last days: Int = 14) -> [(day: Date, total: Double)] {
        guard let unit = preferredUnit else { return [] }
        let start = calendar.startOfDay(for: Date())
        let daySequence = (0 ..< days).compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }.reversed()
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        return daySequence.map { day in
            let total = (grouped[day] ?? []).compactMap { ev -> Double? in
                guard let dose = ev.dose, dose.unit == unit else { return nil }
                return dose.amount
            }.reduce(0, +)
            return (day, total)
        }
    }

    // Average per day over the last window (default 7 days)
    func averagePerDay(window days: Int = 7) -> Double {
        let totals = dailyTotals(last: days)
        guard !totals.isEmpty else { return 0 }
        let sum = totals.map { $0.total }.reduce(0, +)
        return sum / Double(totals.count)
    }

    // Days until refill date (if set)
    var daysUntilRefill: Int? {
        guard let date = selectedMedication?.nextRefillDate else { return nil }
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    // Estimated days remaining from quantity and avg usage
    var estimatedDaysRemaining: Int? {
        refillProjection?.estimatedDaysRemaining
    }

    // MARK: - Usage Progress Metrics

    /// Returns the percentage of medication used (0-100) if both initial and current quantities are available
    var usagePercentage: Double? {
        guard let initial = selectedMedication?.initialQuantity,
              let current = selectedMedication?.quantity,
              initial > 0
        else {
            return nil
        }
        let used = initial - current
        return max(0, min(100, (used / initial) * 100))
    }

    /// Returns a formatted string representing usage (e.g., "50% used (30/60 pills)")
    var usageProgressText: String? {
        guard let initial = selectedMedication?.initialQuantity,
              let current = selectedMedication?.quantity,
              let percentage = usagePercentage,
              let unit = preferredUnit
        else {
            return nil
        }
        let used = initial - current
        return String(format: "%.0f%% used (%.0f/%.0f %@)",
                      percentage, used, initial, unit.abbreviation)
    }

    /// Enum representing whether usage is on track with refill schedule
    enum RefillCycleStatus {
        case onTrack
        case ahead // Using slower than expected
        case behind // Using faster than expected
        case unknown
    }

    /// Compares usage rate to refill schedule and returns status
    var refillCycleStatus: RefillCycleStatus {
        // Need both dates and quantities
        guard let lastRefill = selectedMedication?.lastRefillDate,
              let nextRefill = selectedMedication?.nextRefillDate,
              let initial = selectedMedication?.initialQuantity,
              let current = selectedMedication?.quantity,
              initial > 0
        else {
            return .unknown
        }

        let now = Date()
        let totalCycleDays = calendar.dateComponents([.day], from: lastRefill, to: nextRefill).day ?? 0
        let daysElapsed = calendar.dateComponents([.day], from: lastRefill, to: now).day ?? 0

        guard totalCycleDays > 0, daysElapsed > 0 else { return .unknown }

        // Calculate expected vs actual usage
        let timeProgress = Double(daysElapsed) / Double(totalCycleDays)
        let usedAmount = initial - current
        let usageProgress = usedAmount / initial

        // Allow 10% tolerance
        let tolerance = 0.10

        if abs(usageProgress - timeProgress) <= tolerance {
            return .onTrack
        } else if usageProgress < timeProgress {
            return .ahead // Using slower
        } else {
            return .behind // Using faster
        }
    }

    /// Returns a user-friendly description of refill cycle status
    var refillCycleStatusText: String {
        switch refillCycleStatus {
        case .onTrack:
            return String(localized: "On track")
        case .ahead:
            return String(localized: "Using slower than schedule")
        case .behind:
            return String(localized: "Using faster than schedule")
        case .unknown:
            return "—"
        }
    }

    // Calendar heatmap data for the last N days
    func calendarHeatmapData(last days: Int = 30) -> [CalendarDay] {
        guard let unit = preferredUnit else { return [] }

        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate

        // Create all days in the range
        var allDays: [Date] = []
        var currentDate = startDate
        while currentDate <= endDate {
            allDays.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Group events by day
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }

        // Calculate max total for intensity scaling
        let allTotals = grouped.values.map { dayEvents in
            dayEvents.compactMap { ev -> Double? in
                guard let dose = ev.dose, dose.unit == unit else { return nil }
                return dose.amount
            }.reduce(0, +)
        }
        let maxTotal = allTotals.max() ?? 1

        // Create calendar days with usage data
        return allDays.map { day in
            let dayEvents = grouped[day] ?? []
            let total = dayEvents.compactMap { ev -> Double? in
                guard let dose = ev.dose, dose.unit == unit else { return nil }
                return dose.amount
            }.reduce(0, +)

            let intensity = maxTotal > 0 ? total / maxTotal : 0
            return CalendarDay(date: day, total: total, intensity: intensity)
        }
    }

    var patternSummary: String {
        guard !events.isEmpty else {
            return "Log a few doses to see timing patterns."
        }

        let preferredTimeBucket = mostCommonTimeBucket()
        let recentAverage = averagePerDay(window: 7)
        let priorAverage = averagePerDay(daysEnding: 7, window: 7)

        var fragments: [String] = []
        fragments.append("Use is most often clustered in the \(preferredTimeBucket).")

        if recentAverage > priorAverage * 1.2, priorAverage > 0 {
            fragments.append("Your recent pace is higher than the week before.")
        } else if priorAverage > recentAverage * 1.2, recentAverage > 0 {
            fragments.append("Your recent pace is lighter than the week before.")
        } else {
            fragments.append("Your recent pace looks fairly steady.")
        }

        if let refillProjection {
            fragments.append(refillProjection.statusMessage)
        }

        return fragments.joined(separator: " ")
    }

    func questionContext(windowDays: Int) -> TrendsQuestionContext? {
        guard let medication = selectedMedication,
              let unit = preferredUnit
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let dailyTotalsSummary = dailyTotals(last: windowDays).map { item in
            TrendsQuestionDailyTotal(
                dayLabel: formatter.string(from: item.day),
                total: item.total
            )
        }

        let refillSummary = refillProjection?.statusMessage ?? "No refill projection available yet."
        let quantitySummary: String
        if let quantity = medication.quantity {
            quantitySummary = "\(quantity.formattedAmount) \(unit.abbreviation)s left."
        } else {
            quantitySummary = "Current quantity is not being tracked."
        }

        return TrendsQuestionContext(
            medicationName: medication.displayName,
            unitName: unit.displayName,
            windowDays: windowDays,
            dailyTotals: dailyTotalsSummary,
            patternSummary: patternSummary,
            refillSummary: refillSummary,
            quantitySummary: quantitySummary
        )
    }

    func ask(question: String, windowDays: Int) async {
        guard let context = questionContext(windowDays: windowDays) else {
            questionErrorMessage = "Select a medication with recent dose data first."
            return
        }

        isAnsweringQuestion = true
        questionErrorMessage = nil

        defer {
            isAnsweringQuestion = false
        }

        do {
            latestQuestionAnswer = try await questionService.answer(question: question, context: context)
        } catch {
            latestQuestionAnswer = nil
            questionErrorMessage = error.localizedDescription
        }
    }

    private func averagePerDay(daysEnding endOffset: Int, window days: Int) -> Double {
        let totals = dailyTotals(last: endOffset + days)
        guard totals.count >= days else {
            return 0
        }

        let slice = totals.dropLast(endOffset).suffix(days)
        guard !slice.isEmpty else {
            return 0
        }

        let sum = slice.map(\.total).reduce(0, +)
        return sum / Double(slice.count)
    }

    private func mostCommonTimeBucket() -> String {
        let bucketCounts = events.reduce(into: [String: Int]()) { counts, event in
            let hour = calendar.component(.hour, from: event.date)
            let bucket: String

            switch hour {
            case 5 ..< 12:
                bucket = "morning"
            case 12 ..< 17:
                bucket = "afternoon"
            case 17 ..< 22:
                bucket = "evening"
            default:
                bucket = "night"
            }

            counts[bucket, default: 0] += 1
        }

        return bucketCounts.max { $0.value < $1.value }?.key ?? "day"
    }
}

struct CalendarDay {
    let date: Date
    let total: Double
    let intensity: Double // 0.0 to 1.0 for color intensity
}

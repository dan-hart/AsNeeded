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
	/// Whether private questions can be asked right now. Checked once at creation and on
	/// `refreshQuestionAvailability()`, because the on-device model availability check is a system call
	/// that should not run on every render.
	@Published private(set) var questionAvailability: TrendsQuestionAvailability = .unavailable
	/// Why questions are unavailable on this device, when they are.
	@Published private(set) var questionUnavailableReason: TrendsQuestionUnavailableReason?
    @Published var latestQuestionAnswer: TrendsQuestionAnswer?
    @Published var isAnsweringQuestion = false
    @Published var questionErrorMessage: String?
	/// Where the private-questions flow currently is. Drives the working, answered, and failed states in the UI.
	@Published private(set) var questionPhase: TrendsQuestionPhase = .idle
	/// The question that produced `questionPhase`'s current answer or error, echoed back in the UI.
	@Published private(set) var askedQuestion: String?
	private var questionTask: Task<Void, Never>?
	/// Identifies the question currently allowed to publish state. A superseded or cancelled task
	/// compares against this before writing, so it can never clobber its replacement.
	private var questionGeneration = UUID()

    private let dataStore: DataStore
    private let refillProfileStore: MedicationRefillProfileStore
    private let refillProjectionService: MedicationRefillProjectionService
    private let questionService: MedicationTrendsQuestionService
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
	private var storeObservationTasks: [Task<Void, Never>] = []

	/// The selected medication's dose events, filtered and sorted once per change of the underlying
	/// store or the selection. `source` is the store array the result was derived from; comparing it
	/// against the store's current array is constant time while the store is unchanged.
	private struct SelectedEventsCache {
		let source: [ANEventConcept]
		let medicationID: UUID?
		let events: [ANEventConcept]
	}

	private struct DailyTotalsKey: Hashable {
		let days: Int
		let unit: ANUnitConcept
	}

	private var selectedEventsCache: SelectedEventsCache?
	private var dailyTotalsCache: [DailyTotalsKey: [(day: Date, total: Double)]] = [:]
	private var dailyTotalsCacheDay: Date?

    init(
        dataStore: DataStore = .shared,
        selectedMedicationID: UUID? = nil,
        refillProfileStore: MedicationRefillProfileStore = .shared,
        refillProjectionService: MedicationRefillProjectionService = MedicationRefillProjectionService(),
        questionService: MedicationTrendsQuestionService = MedicationTrendsQuestionService()
    ) {
        self.dataStore = dataStore
        self.refillProfileStore = refillProfileStore
        self.refillProjectionService = refillProjectionService
        self.questionService = questionService
        if let initialID = selectedMedicationID {
            self.selectedMedicationID = initialID
        }

        // Load initial data and observe changes
        loadData()
        observeStoreChanges()
		refreshQuestionAvailability()

        // Ensure we have a valid selection
        ensureValidSelection()
    }

	deinit {
		storeObservationTasks.forEach { $0.cancel() }
	}

    private func loadData() {
        medications = dataStore.medications
    }

	/// Follows the Boutique stores' event streams so the view updates the moment data loads or changes.
	/// The streams replay their latest event on subscription, which also covers a store that finished
	/// loading from disk before this view model was created.
    private func observeStoreChanges() {
		let medicationsStore = dataStore.medicationsStore
		let eventsStore = dataStore.eventsStore

		storeObservationTasks = [
			Task { [weak self] in
				for await event in medicationsStore.events {
					guard !Task.isCancelled else { return }
					if case .initialized = event.operation { continue }
					self?.refreshMedications()
				}
			},
			Task { [weak self] in
				for await event in eventsStore.events {
					guard !Task.isCancelled else { return }
					if case .initialized = event.operation { continue }
					// `events` re-derives lazily from the store; the view just needs to know to re-read it.
					self?.objectWillChange.send()
				}
			},
		]

		NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
			.sink { [weak self] _ in
				Task { @MainActor in
					self?.refreshQuestionAvailability()
				}
			}
			.store(in: &cancellables)
    }

	private func refreshMedications() {
		let latest = dataStore.medications
		guard latest != medications else { return }
		medications = latest
		ensureValidSelection()
	}

	/// Re-checks whether private questions are available, for example after the user enables Apple
	/// Intelligence or toggles the feature in Settings.
	func refreshQuestionAvailability() {
		let availability = questionService.availability
		let reason = questionService.unavailableReason
		if availability != questionAvailability {
			questionAvailability = availability
		}
		if reason != questionUnavailableReason {
			questionUnavailableReason = reason
		}
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

    var refillProfile: MedicationRefillProfile {
        guard let medication = selectedMedication else {
            return .empty
        }

        return refillProfileStore.profile(for: medication.id)
    }

    var events: [ANEventConcept] {
		let source = dataStore.events
		let medicationID = selectedMedicationID
		if let cache = selectedEventsCache,
		   cache.medicationID == medicationID,
		   cache.source == source
		{
			return cache.events
		}

		let filtered = Self.doseEvents(in: source, for: medicationID)
		selectedEventsCache = SelectedEventsCache(source: source, medicationID: medicationID, events: filtered)
		dailyTotalsCache.removeAll()
		return filtered
    }

	/// Dose-taken events for one medication, oldest first.
	private static func doseEvents(in events: [ANEventConcept], for medicationID: UUID?) -> [ANEventConcept] {
		guard let medicationID else { return [] }
		return events
			.filter { event in
				guard let eventMedication = event.medication,
				      eventMedication.id == medicationID,
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

    var refillProjection: MedicationRefillProjectionService.RefillProjection? {
        guard let medication = selectedMedication else {
            return nil
        }

        return refillProjectionService.projection(
            for: medication,
            events: events,
            profile: refillProfile
        )
    }

    var summaryAccessibilityLabel: String {
        guard let medication = selectedMedication else {
            return ""
        }

        var components = ["\(medication.displayName).", patternSummary]
        if let refillProjection {
            components.append(refillProjection.urgent ? "Urgent refill status." : "Refill status.")
            if !patternSummary.contains(refillProjection.statusMessage) {
                components.append(refillProjection.statusMessage)
            }
        }
        return components.joined(separator: " ")
    }

    var examplePrompts: [String] {
        guard let medication = selectedMedication else {
            return []
        }

        return questionService.examplePrompts(for: medication)
    }

	/// The most recent day the trends cover: yesterday. Today is still in progress, so including it would
	/// make every chart end in a dip and drag the averages down.
	var trendsWindowEnd: Date {
		let today = calendar.startOfDay(for: Date())
		return calendar.date(byAdding: .day, value: -1, to: today) ?? today
	}

    // Daily totals for the last N complete days ending yesterday (default 14)
    func dailyTotals(last days: Int = 14) -> [(day: Date, total: Double)] {
		// Reading `events` first refreshes the cache when the store or selection changed.
		let events = self.events
        guard let unit = preferredUnit else { return [] }
        let start = trendsWindowEnd

		if dailyTotalsCacheDay != start {
			dailyTotalsCache.removeAll()
			dailyTotalsCacheDay = start
		}
		let key = DailyTotalsKey(days: days, unit: unit)
		if let cached = dailyTotalsCache[key] {
			return cached
		}

        let daySequence = (0 ..< days).compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }.reversed()
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        let totals = daySequence.map { day in
            let total = (grouped[day] ?? []).compactMap { ev -> Double? in
                guard let dose = ev.dose, dose.unit == unit else { return nil }
                return dose.amount
            }.reduce(0, +)
            return (day: day, total: total)
        }
		dailyTotalsCache[key] = totals
		return totals
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

    // Calendar heatmap data for the last N complete days ending yesterday
    func calendarHeatmapData(last days: Int = 30) -> [CalendarDay] {
        guard let unit = preferredUnit else { return [] }

        let endDate = trendsWindowEnd
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
			questionPhase = .failed(questionErrorMessage ?? "")
            return
        }

		questionTask?.cancel()
		let generation = UUID()
		questionGeneration = generation
		let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
		askedQuestion = trimmedQuestion
        isAnsweringQuestion = true
        questionErrorMessage = nil
		latestQuestionAnswer = nil
		questionPhase = .preparing

		let task = Task { [questionService] in
			var latest: TrendsQuestionAnswer?
			do {
				for try await partial in questionService.streamAnswer(question: trimmedQuestion, context: context) {
					try Task.checkCancellation()
					guard questionGeneration == generation else { return }
					latest = partial
					questionPhase = .generating(partial)
				}
				try Task.checkCancellation()
				guard questionGeneration == generation else { return }
				if let answer = latest, !answer.answer.isEmpty {
					latestQuestionAnswer = answer
					questionPhase = .answered(answer)
				} else {
					questionErrorMessage = String(localized: "No answer came back. Try rephrasing the question.")
					questionPhase = .failed(questionErrorMessage ?? "")
				}
			} catch is CancellationError {
				guard questionGeneration == generation else { return }
				questionPhase = .idle
			} catch {
				guard questionGeneration == generation else { return }
				latestQuestionAnswer = nil
				questionErrorMessage = error.localizedDescription
				questionPhase = .failed(error.localizedDescription)
			}
			guard questionGeneration == generation else { return }
			isAnsweringQuestion = false
			questionTask = nil
		}
		questionTask = task
		await task.value
    }

	/// Stops an in-progress question and returns to the idle state.
	func cancelQuestion() {
		questionTask?.cancel()
		questionTask = nil
		questionGeneration = UUID()
		isAnsweringQuestion = false
		questionPhase = .idle
	}

	/// Clears the current answer or error so a new question can be asked.
	func resetQuestion() {
		questionTask?.cancel()
		questionTask = nil
		questionGeneration = UUID()
		isAnsweringQuestion = false
		latestQuestionAnswer = nil
		questionErrorMessage = nil
		askedQuestion = nil
		questionPhase = .idle
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

// MARK: - Question Phase

/// The lifecycle of one private question, from idle through generation to a result.
enum TrendsQuestionPhase: Equatable {
	case idle
	/// The context is built and the model has been asked; nothing has come back yet.
	case preparing
	/// The model is streaming; the payload is the most complete partial answer so far.
	case generating(TrendsQuestionAnswer)
	case answered(TrendsQuestionAnswer)
	case failed(String)

	var isWorking: Bool {
		switch self {
		case .preparing, .generating:
			return true
		case .idle, .answered, .failed:
			return false
		}
	}
}

// WidgetDataProvider.swift
// Data provider for widget using App Group shared storage

import ANModelKit
import Boutique
import Foundation
import WidgetKit
import UserNotifications

/// Provides medication data to widgets via App Group shared storage
@MainActor
final class WidgetDataProvider {
    static let shared = WidgetDataProvider()

    // App Group identifier matching main app
    let appGroupIdentifier = "group.com.codedbydan.AsNeeded"
    private let decoder = JSONDecoder()
    private let guidanceService = WidgetMedicationGuidanceService()

	private let transactions: MedicationPersistenceTransactions?
	private var snapshot: MedicationPersistenceSnapshot?
	var isUnavailable: Bool { snapshot == nil }

    init() {
        // Get shared container URL for App Group
        guard let sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ),
            let medicationsEngine = SQLiteStorageEngine(
                directory: FileManager.Directory(url: sharedContainerURL),
                databaseFilename: "medications"
            ),
            let eventsEngine = SQLiteStorageEngine(
                directory: FileManager.Directory(url: sharedContainerURL),
                databaseFilename: "events"
            )
        else {
			transactions = nil
			return
        }

        let medicationsStore = Store<ANMedicationConcept>(
            storage: medicationsEngine,
            cacheIdentifier: \ANMedicationConcept.id.uuidString
        )

        let eventsStore = Store<ANEventConcept>(
            storage: eventsEngine,
            cacheIdentifier: \ANEventConcept.id.uuidString
        )
		transactions = MedicationPersistenceTransactions(
			directory: sharedContainerURL,
			medicationsStore: medicationsStore,
			eventsStore: eventsStore,
			preferences: [:]
		)
    }

    // MARK: - Public Interface

	/// Read once under the cross-process transaction lock before constructing an entry.
	func loadSnapshot() async {
		do {
			guard let transactions else { throw PersistenceTransactionError.storageUnavailable }
			snapshot = try await transactions.read()
		} catch {
			// Recovery or lock failure must never expose cached timing as clearance.
			snapshot = nil
		}
	}

	func recordDose(medicationID: UUID) async throws {
		guard let transactions else { throw PersistenceTransactionError.storageUnavailable }
		let recorder = WidgetDoseRecorder(commit: { id, date in
			try await transactions.perform { snapshot in
				try WidgetDoseRecordingPolicy.recordDose(medicationID: id, in: &snapshot,
					at: date, profile: self.safetyProfiles[id.uuidString] ?? .empty)
			}
		}, reconcile: { id in
			await WidgetDoseNotificationReconciler(client: .live(UNUserNotificationCenter.current()),
				readSnapshot: { try await transactions.read() }, profiles: { self.safetyProfiles })
				.reconcile(afterLogging: id)
		})
		try await recorder.recordDose(medicationID: medicationID)
	}

    /// Get all active medications
    var medications: [ANMedicationConcept] {
        (snapshot?.medications ?? []).filter { !$0.isArchived }
    }

    /// Get all events
    var events: [ANEventConcept] {
        snapshot?.events ?? []
    }

    /// Get medications sorted alphabetically by display name
    var medicationsByName: [ANMedicationConcept] {
        medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var safetyProfiles: [String: MedicationSafetyProfile] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "medicationSafetyProfiles"),
              let profiles = try? decoder.decode([String: MedicationSafetyProfile].self, from: data)
        else {
            return [:]
        }

        return profiles
    }

    private func safetyProfile(for medication: ANMedicationConcept) -> MedicationSafetyProfile {
        safetyProfiles[medication.id.uuidString] ?? .empty
    }

    /// Get the next medication due to be taken
    var nextMedicationDue: ANMedicationConcept? {
        medications.min { left, right in
            let leftDate = nextDoseTime(for: left) ?? .distantPast
            let rightDate = nextDoseTime(for: right) ?? .distantPast

            if leftDate == rightDate {
                return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
            }

            return leftDate < rightDate
        }
    }

    /// Calculate next dose time for a medication using the saved safety profile when available
    func nextDoseTime(for medication: ANMedicationConcept) -> Date? {
		MedicationDoseGuidanceService().nextEligibleDate(for: medication,
			events: events, profile: safetyProfile(for: medication))
    }

    /// Check if medication can be taken now
    func canTakeNow(_ medication: ANMedicationConcept) -> Bool {
		MedicationDoseGuidanceService().canTakeNow(medication: medication,
			events: events, profile: safetyProfile(for: medication))
    }

	/// Logging remains available without claiming that unknown guidance is clearance.
	func canLogDose(_ medication: ANMedicationConcept) -> Bool {
		!isUnavailable && WidgetDoseRecordingPolicy.canLogDose(medication: medication,
			events: events, profile: safetyProfile(for: medication))
	}

    /// Get time remaining until next dose
    func timeUntilNextDose(for medication: ANMedicationConcept) -> TimeInterval? {
        guard let nextTime = nextDoseTime(for: medication) else {
            return nil
        }

        let interval = nextTime.timeIntervalSince(Date())
        return max(0, interval)
    }

    /// Get medications that are low on quantity (< 10)
    var lowQuantityMedications: [ANMedicationConcept] {
        medications.filter { medication in
            guidanceService.refillProjection(
                for: medication,
                events: events,
                profile: safetyProfile(for: medication)
            ).lowStock
        }
    }

    /// Get medications that need refill soon
    var refillDueSoon: [ANMedicationConcept] {
        medications.filter { medication in
            guidanceService.refillProjection(
                for: medication,
                events: events,
                profile: safetyProfile(for: medication)
            ).refillSoon
        }
    }

    func refillStatusMessage(for medication: ANMedicationConcept) -> String {
        guidanceService.refillProjection(
            for: medication,
            events: events,
            profile: safetyProfile(for: medication)
        ).statusMessage
    }
}

// MARK: - Helper Extensions

extension ANMedicationConcept {
    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return nickname
        }
        return clinicalName
    }

    /// Returns the display color for this medication, falling back to blue if none set
    var displayColor: Color {
        if let hexColor = displayColorHex {
            return Color(hex: hexColor) ?? .blue
        }
        return .blue
    }

    // Default symbol based on medication unit type
    var defaultSymbol: String {
        if let unit = prescribedUnit {
            switch unit {
            case .puff:
                return "wind"
            case .drop:
                return "drop.fill"
            case .spray:
                return "humidity"
            case .injection:
                return "syringe.fill"
            case .patch:
                return "bandage.fill"
            case .lozenge:
                return "circle.fill"
            case .suppository:
                return "capsule.fill"
            case .tablet:
                return "pills.fill"
            case .capsule:
                return "capsule.portrait.fill"
            default:
                return "pills.fill"
            }
        }
        return "pills.fill"
    }

    // Display symbol with fallback to default
    var effectiveDisplaySymbol: String {
        symbolInfo?.name ?? defaultSymbol
    }
}

// MARK: - Color Hex Extension

import SwiftUI

extension Color {
    init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

private struct WidgetMedicationGuidanceService {
    struct RefillProjection {
        let lowStock: Bool
        let refillSoon: Bool
        let statusMessage: String
    }

    private let calendar = Calendar.current

    func refillProjection(
        for medication: ANMedicationConcept,
        events: [ANEventConcept],
        profile: MedicationSafetyProfile
    ) -> RefillProjection {
        let threshold = profile.lowStockThreshold ?? 10
        let lowStock = medication.quantity != nil && (medication.quantity ?? 0) <= threshold
        let leadDays = profile.refillLeadDays
        let averageDailyUsage = averageDailyUsage(for: medication, events: events)
        let estimatedDaysRemaining: Int? = {
            guard let quantity = medication.quantity, quantity > 0, averageDailyUsage > 0 else {
                return nil
            }

            return max(0, Int((quantity / averageDailyUsage).rounded(.down)))
        }()
        let daysUntilRefill = medication.nextRefillDate.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: $0)).day
        }
        let refillSoon = lowStock ||
            (daysUntilRefill != nil && (daysUntilRefill ?? .max) <= leadDays) ||
            (estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= leadDays)
        let statusMessage: String

        if lowStock {
            statusMessage = "Refill prep would be timely."
        } else if refillSoon {
            statusMessage = "You’re approaching your refill window."
        } else if let estimatedDaysRemaining {
            statusMessage = "About \(estimatedDaysRemaining)d of supply at your recent pace."
        } else {
            statusMessage = "Log more doses to estimate your run-out date."
        }

        return RefillProjection(
            lowStock: lowStock,
            refillSoon: refillSoon,
            statusMessage: statusMessage
        )
    }

    private func averageDailyUsage(for medication: ANMedicationConcept, events: [ANEventConcept]) -> Double {
        let relevantEvents = events.filter { event in
            event.eventType == .doseTaken &&
                event.medication?.id == medication.id &&
                (medication.prescribedUnit == nil || event.dose?.unit == medication.prescribedUnit)
        }

        guard !relevantEvents.isEmpty else {
            return 0
        }

        let grouped = Dictionary(grouping: relevantEvents) { event in
            calendar.startOfDay(for: event.date)
        }
        let total = relevantEvents.compactMap { $0.dose?.amount }.reduce(0, +)
        return total / Double(max(1, grouped.count))
    }
}

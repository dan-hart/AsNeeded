// WidgetDataProvider.swift
// Data provider for widget using App Group shared storage

import ANModelKit
import Boutique
import Foundation
import WidgetKit

/// Provides medication data to widgets via App Group shared storage
@MainActor
final class WidgetDataProvider {
    static let shared = WidgetDataProvider()

    // App Group identifier matching main app
    let appGroupIdentifier = "group.com.codedbydan.AsNeeded"
    private let decoder = JSONDecoder()
    private let refillProjectionService = WidgetMedicationRefillProjectionService()
    private let eligibilityService = WidgetMedicationEligibilityService()

    // Boutique stores using shared App Group container - made internal for widget intent access
    let medicationsStore: Store<ANMedicationConcept>
    let eventsStore: Store<ANEventConcept>

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
            // If any initialization fails, widget will show empty state
            // This is acceptable as widgets fail gracefully
            fatalError("Unable to initialize widget data provider. Widget will not function.")
        }

        medicationsStore = Store<ANMedicationConcept>(
            storage: medicationsEngine,
            cacheIdentifier: \ANMedicationConcept.id.uuidString
        )

        eventsStore = Store<ANEventConcept>(
            storage: eventsEngine,
            cacheIdentifier: \ANEventConcept.id.uuidString
        )
    }

    // MARK: - Public Interface

    /// Get all active medications
    var medications: [ANMedicationConcept] {
        medicationsStore.items.filter { !$0.isArchived }
    }

    /// Get all events
    var events: [ANEventConcept] {
        eventsStore.items
    }

    /// Get medications sorted alphabetically by display name
    var medicationsByName: [ANMedicationConcept] {
        medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var refillProfiles: [String: WidgetMedicationRefillProfile] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return [:]
        }

        if defaults.object(forKey: WidgetUserDefaultsKeys.medicationRefillProfiles) != nil {
            guard
                let data = defaults.data(forKey: WidgetUserDefaultsKeys.medicationRefillProfiles),
                let profiles = try? decoder.decode([String: WidgetMedicationRefillProfile].self, from: data)
            else {
                return [:]
            }
            return profiles
        }

        guard
            let data = defaults.data(forKey: WidgetUserDefaultsKeys.legacyMedicationSafetyProfiles),
            let profiles = try? decoder.decode([String: WidgetMedicationRefillProfile].self, from: data)
        else {
            return [:]
        }
        return profiles
    }

    private var legacyEligibilityProfiles: [String: WidgetMedicationEligibilityProfile] {
        guard
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let data = defaults.data(forKey: WidgetUserDefaultsKeys.legacyMedicationSafetyProfiles),
            let profiles = try? decoder.decode([String: WidgetMedicationEligibilityProfile].self, from: data)
        else {
            return [:]
        }
        return profiles
    }

    private func refillProfile(for medication: ANMedicationConcept) -> WidgetMedicationRefillProfile {
        refillProfiles[medication.id.uuidString] ?? .empty
    }

    private func eligibilityProfile(for medication: ANMedicationConcept) -> WidgetMedicationEligibilityProfile {
        legacyEligibilityProfiles[medication.id.uuidString] ?? .empty
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

    /// Temporary compatibility for widgets that still display legacy eligibility state.
    func nextDoseTime(for medication: ANMedicationConcept) -> Date? {
        eligibilityService.nextEligibleDate(
            for: medication,
            events: events,
            profile: eligibilityProfile(for: medication)
        )
    }

    /// Check if medication can be taken now
    func canTakeNow(_ medication: ANMedicationConcept) -> Bool {
        guard let nextTime = nextDoseTime(for: medication) else {
            return true
        }
        return nextTime <= Date()
    }

    /// Get time remaining until next dose
    func timeUntilNextDose(for medication: ANMedicationConcept) -> TimeInterval? {
        guard let nextTime = nextDoseTime(for: medication) else {
            return nil
        }

        let interval = nextTime.timeIntervalSince(Date())
        return max(0, interval)
    }

    /// Get medications at or below their saved low-stock threshold.
    var lowQuantityMedications: [ANMedicationConcept] {
        medications.filter { medication in
            refillProjectionService.projection(
                for: medication,
                events: events,
                profile: refillProfile(for: medication)
            ).lowStock
        }
    }

    /// Get medications that need refill soon
    var refillDueSoon: [ANMedicationConcept] {
        medications.filter { medication in
            refillProjectionService.projection(
                for: medication,
                events: events,
                profile: refillProfile(for: medication)
            ).refillSoon
        }
    }

    func refillStatusMessage(for medication: ANMedicationConcept) -> String {
        refillProjectionService.projection(
            for: medication,
            events: events,
            profile: refillProfile(for: medication)
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

private enum WidgetUserDefaultsKeys {
    static let medicationRefillProfiles = "medicationRefillProfiles"
    static let legacyMedicationSafetyProfiles = "medicationSafetyProfiles"
}

private struct WidgetMedicationRefillProfile: Codable {
    static let empty = WidgetMedicationRefillProfile()

    var lowStockThreshold: Double?
}

private struct WidgetMedicationEligibilityProfile: Codable {
    static let empty = WidgetMedicationEligibilityProfile()

    var minimumHoursBetweenDoses: Double?
}

private struct WidgetMedicationRefillProjectionService {
    struct RefillProjection {
        let lowStock: Bool
        let refillSoon: Bool
        let statusMessage: String
    }

    private let calendar = Calendar.current

    func projection(
        for medication: ANMedicationConcept,
        events: [ANEventConcept],
        profile: WidgetMedicationRefillProfile
    ) -> RefillProjection {
        let threshold = profile.lowStockThreshold ?? 10
        let lowStock = medication.quantity != nil && (medication.quantity ?? 0) <= threshold
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
            (daysUntilRefill != nil && (daysUntilRefill ?? .max) <= 5) ||
            (estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= 5)
        let urgent = lowStock ||
            (daysUntilRefill != nil && (daysUntilRefill ?? .max) <= 2) ||
            (estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= 2)
        let statusMessage: String

        if medication.quantity == nil {
            statusMessage = "Add or update the quantity to see refill estimates."
        } else if urgent {
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

private struct WidgetMedicationEligibilityService {
    func nextEligibleDate(
        for medication: ANMedicationConcept,
        events: [ANEventConcept],
        profile: WidgetMedicationEligibilityProfile
    ) -> Date? {
        guard let minimumHoursBetweenDoses = profile.minimumHoursBetweenDoses else {
            return nil
        }

        let lastEvent = events
            .filter { $0.eventType == .doseTaken && $0.medication?.id == medication.id }
            .sorted { $0.date > $1.date }
            .first

        guard let lastEvent else {
            return nil
        }

        return lastEvent.date.addingTimeInterval(minimumHoursBetweenDoses * 3600)
    }
}

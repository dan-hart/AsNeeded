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

    private func refillProfile(for medication: ANMedicationConcept) -> WidgetMedicationRefillProfile {
        refillProfiles[medication.id.uuidString] ?? .empty
    }

    // MARK: - Refill Snapshot
    /// Active medications plus their refill projections, computed once per timeline pass.
    ///
    /// Building this requires one decode of the refill profiles and one read of the events store,
    /// after which every refill-related accessor is a dictionary lookup instead of a full event scan.
    private struct RefillSnapshot {
        let medications: [ANMedicationConcept]
        let projections: [UUID: WidgetMedicationRefillProjectionService.RefillProjection]

        func lowStock(_ medication: ANMedicationConcept) -> Bool {
            projections[medication.id]?.lowStock ?? false
        }

        func refillSoon(_ medication: ANMedicationConcept) -> Bool {
            projections[medication.id]?.refillSoon ?? false
        }
    }

    private var cachedRefillSnapshot: RefillSnapshot?

    private var refillSnapshot: RefillSnapshot {
        if let cachedRefillSnapshot {
            return cachedRefillSnapshot
        }

        let medications = self.medications
        let events = self.events
        let profiles = refillProfiles
        let projectionDate = Date.now
        var projections: [UUID: WidgetMedicationRefillProjectionService.RefillProjection] = [:]
        projections.reserveCapacity(medications.count)

        for medication in medications {
            projections[medication.id] = refillProjectionService.projection(
                for: medication,
                at: projectionDate,
                events: events,
                profile: profiles[medication.id.uuidString] ?? .empty
            )
        }

        let snapshot = RefillSnapshot(medications: medications, projections: projections)
        cachedRefillSnapshot = snapshot
        return snapshot
    }

    /// Discard the cached refill snapshot so the next refill read rebuilds it from the current store contents.
    ///
    /// The provider is a process-lifetime singleton, so each timeline pass must call this before reading
    /// refill data; otherwise a later refresh could reuse projections from a previous pass.
    func invalidateRefillSnapshot() {
        cachedRefillSnapshot = nil
    }

    /// Sort low-stock medications first, then refill-soon medications, then alphabetically.
    var medicationsByRefillPriority: [ANMedicationConcept] {
        let snapshot = refillSnapshot

        return snapshot.medications.sorted { left, right in
            let leftPriority = snapshot.lowStock(left) ? 0 : snapshot.refillSoon(left) ? 1 : 2
            let rightPriority = snapshot.lowStock(right) ? 0 : snapshot.refillSoon(right) ? 1 : 2

            if leftPriority == rightPriority {
                let nameComparison = left.displayName.localizedCaseInsensitiveCompare(right.displayName)
                if nameComparison == .orderedSame {
                    return left.id.uuidString < right.id.uuidString
                }
                return nameComparison == .orderedAscending
            }

            return leftPriority < rightPriority
        }
    }

    /// Feature the highest-priority medication for compact widgets.
    var featuredMedication: ANMedicationConcept? {
        medicationsByRefillPriority.first
    }

    /// Get medications at or below their saved low-stock threshold.
    var lowQuantityMedications: [ANMedicationConcept] {
        let snapshot = refillSnapshot
        return snapshot.medications.filter { snapshot.lowStock($0) }
    }

    /// Get medications that need refill soon
    var refillDueSoon: [ANMedicationConcept] {
        let snapshot = refillSnapshot
        return snapshot.medications.filter { snapshot.refillSoon($0) }
    }

    func refillStatusMessage(for medication: ANMedicationConcept) -> String {
        if let projection = refillSnapshot.projections[medication.id] {
            return projection.statusMessage
        }

        // Medication is not part of the active snapshot (e.g. archived); project it directly.
        return refillProjectionService.projection(
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

private struct WidgetMedicationRefillProjectionService {
    struct RefillProjection {
        let lowStock: Bool
        let refillSoon: Bool
        let statusMessage: String
    }

    private let calendar = Calendar.current

    func projection(
        for medication: ANMedicationConcept,
        at date: Date = .now,
        events: [ANEventConcept],
        profile: WidgetMedicationRefillProfile
    ) -> RefillProjection {
        let filteredEvents = events
            .filter { event in
                event.eventType == .doseTaken &&
                    event.medication?.id == medication.id &&
                    event.date <= date
            }
            .sorted { $0.date < $1.date }
        let averageDailyUsage = averageDailyUsage(
            for: filteredEvents,
            preferredUnit: medication.prescribedUnit
        )
        let estimatedDaysRemaining: Int? = {
            guard let quantity = medication.quantity, quantity > 0, averageDailyUsage > 0 else {
                return nil
            }

            return max(0, Int((quantity / averageDailyUsage).rounded(.down)))
        }()
        let threshold = profile.lowStockThreshold ?? 10
        let lowStock = medication.quantity != nil && (medication.quantity ?? 0) <= threshold
        let daysUntilRefill = medication.nextRefillDate.flatMap {
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: $0)
            ).day
        }
        let refillSoon = lowStock ||
            (daysUntilRefill != nil && (daysUntilRefill ?? .max) <= 5) ||
            (estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= 5)
        let urgent = lowStock ||
            (daysUntilRefill != nil && (daysUntilRefill ?? .max) <= 2) ||
            (estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= 2)
        let statusMessage: String

        if urgent {
            statusMessage = "Refill prep would be timely."
        } else if refillSoon {
            statusMessage = "You’re approaching your refill window."
        } else if medication.quantity == nil {
            statusMessage = "Add or update the quantity to see refill estimates."
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

    private func averageDailyUsage(
        for events: [ANEventConcept],
        preferredUnit: ANUnitConcept?
    ) -> Double {
        let relevantEvents = events.filter { event in
            guard let dose = event.dose else {
                return false
            }

            if let preferredUnit {
                return dose.unit == preferredUnit
            }

            return true
        }

        guard !relevantEvents.isEmpty else {
            return 0
        }

        if preferredUnit == nil {
            guard let eventUnit = relevantEvents.first?.dose?.unit,
                  relevantEvents.allSatisfy({ $0.dose?.unit == eventUnit })
            else {
                return 0
            }
        }

        let grouped = Dictionary(grouping: relevantEvents) { event in
            calendar.startOfDay(for: event.date)
        }
        let total = relevantEvents.compactMap { $0.dose?.amount }.reduce(0, +)
        return total / Double(max(1, grouped.count))
    }
}

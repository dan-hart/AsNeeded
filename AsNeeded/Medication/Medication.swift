// Medication.swift
// Defines a persistable Medication model using ANModelKit and sets up a Boutique store.

import ANModelKit
import Boutique
import Foundation

typealias Medication = ANMedicationConcept

extension ANMedicationConcept {
    // Centralized access to the shared medications store.
    @MainActor
    static var store: Store<ANMedicationConcept> { DataStore.shared.medicationsStore }

    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return nickname
        } else if !clinicalName.isEmpty {
            return clinicalName
        } else {
            return "Unknown"
        }
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
                // For units like .milligram, .microgram, etc.
                return "pills.fill"
            }
        }
        return "pills.fill"
    }

    // Display symbol with fallback to default
    var effectiveDisplaySymbol: String {
        symbolInfo?.name ?? defaultSymbol
    }

    // Helper to create ANSymbolInfo from string
    static func createSymbolInfo(from symbolName: String?) -> ANSymbolInfo? {
        guard let symbolName = symbolName else { return nil }
        return ANSymbolInfo(name: symbolName)
    }

    // MARK: - Archived Status

    // NOTE: This is a local extension property. If ANModelKit adds native support
    // for archived status in the future, this extension should be updated or removed.

    /// Storage key for archived status in local app storage
    /// Uses medication ID to track which medications are archived
    private static let archivedMedicationsKey = "archivedMedicationIDs"

    /// Whether this medication is archived
    /// Archived medications are no longer actively used but retained for history
    var isArchived: Bool {
        get {
            let archivedIDs = UserDefaults.standard.array(forKey: Self.archivedMedicationsKey) as? [String] ?? []
            return archivedIDs.contains(id.uuidString)
        }
        set {
            var archivedIDs = UserDefaults.standard.array(forKey: Self.archivedMedicationsKey) as? [String] ?? []
            if newValue {
                if !archivedIDs.contains(id.uuidString) {
                    archivedIDs.append(id.uuidString)
                }
            } else {
                archivedIDs.removeAll { $0 == id.uuidString }
            }
            UserDefaults.standard.set(archivedIDs, forKey: Self.archivedMedicationsKey)
            UserDefaults.standard.synchronize()
        }
    }

    /// Archive this medication
    mutating func archive() {
        isArchived = true
    }

    /// Unarchive this medication
    mutating func unarchive() {
        isArchived = false
    }
}

// MARK: - Medication Filtering Helpers

extension Sequence where Element == ANMedicationConcept {
    /// Filter to only active (non-archived) medications
    var active: [ANMedicationConcept] {
        filter { !$0.isArchived }
    }

    /// Filter to only archived medications
    var archived: [ANMedicationConcept] {
        filter { $0.isArchived }
    }
}

extension ANEventConcept {
    // Centralized access to the shared events store.
    @MainActor
    static var store: Store<ANEventConcept> { DataStore.shared.eventsStore }
}

#if DEBUG
    import SwiftUI

    #Preview("Medication Row Preview - without dose/info fields") {
        MedicationRowComponent(medication: ANMedicationConcept(
            clinicalName: "Ibuprofen",
            nickname: "Ibuprofen"
        )) {
            print("Log dose tapped")
        }
        .padding()
    }

    #Preview("Medication Edit Preview - without dose/info fields") {
        MedicationEditView(
            medication: ANMedicationConcept(
                clinicalName: "Ibuprofen",
                nickname: "Ibuprofen"
            ),
            onSave: { _ in },
            onCancel: {}
        )
    }
#endif

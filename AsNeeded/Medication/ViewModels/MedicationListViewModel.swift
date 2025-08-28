// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import Foundation
import ANModelKit

@MainActor
final class MedicationListViewModel: ObservableObject {
    private let appStore: DataStore

    init(appStore: DataStore = .shared) {
        self.appStore = appStore
    }

    var items: [ANMedicationConcept] { appStore.medications }

    func add(_ med: ANMedicationConcept) async {
        try? await appStore.addMedication(med)
    }

    func update(_ med: ANMedicationConcept) async {
        try? await appStore.updateMedication(med)
    }

    func delete(_ med: ANMedicationConcept) async {
        try? await appStore.deleteMedication(med)
    }
}

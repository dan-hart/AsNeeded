// MedicationDetailViewModel.swift
// View model for medication detail operations via DataStore.

import Foundation
import ANModelKit

@MainActor
final class MedicationDetailViewModel: ObservableObject {
    private let appStore: DataStore

    init(appStore: DataStore = .shared) {
        self.appStore = appStore
    }

    func save(updated medication: ANMedicationConcept) async {
        try? await appStore.updateMedication(medication)
    }

    func delete(_ medication: ANMedicationConcept) async {
        try? await appStore.deleteMedication(medication)
    }

    func log(event: ANEventConcept) async {
        try? await appStore.addEvent(event)
    }
}

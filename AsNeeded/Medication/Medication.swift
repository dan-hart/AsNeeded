// Medication.swift
// Defines a persistable Medication model using ANModelKit and sets up a Boutique store.

import Foundation
import Boutique
import ANModelKit

typealias Medication = ANMedicationConcept

extension ANMedicationConcept {
    // Centralized access to the shared medications store.
    @MainActor
    static var store: Store<ANMedicationConcept> { DataStore.shared.medicationsStore }
    
    var displayName: String { nickname ?? clinicalName }
}

extension ANEventConcept {
    // Centralized access to the shared events store.
    @MainActor
    static var store: Store<ANEventConcept> { DataStore.shared.eventsStore }
}

#if DEBUG
import SwiftUI

#Preview("Medication Row Preview - without dose/info fields") {
    MedicationRow(medication: ANMedicationConcept(
        clinicalName: "Ibuprofen",
        nickname: "Ibuprofen"
    ))
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

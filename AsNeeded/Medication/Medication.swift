// Medication.swift
// Defines a persistable Medication model using ANModelKit and sets up a Boutique store.

import Foundation
import Boutique
import ANModelKit

typealias Medication = ANMedicationConcept

extension ANMedicationConcept {
    @MainActor
    static let store = Store<ANMedicationConcept>(
        storage: SQLiteStorageEngine.default(appendingPath: "medications.sqlite"),
        cacheIdentifier: \ANMedicationConcept.id.uuidString
    )
    
    var displayName: String {
        nickname ?? clinicalName
    }
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

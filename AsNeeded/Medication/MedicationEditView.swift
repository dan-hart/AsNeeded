// MedicationEditView.swift
// SwiftUI view for editing clinicalName and nickname of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit

struct MedicationEditView: View {
    @State private var clinicalName: String
    @State private var nickname: String
    
    let medication: ANMedicationConcept?
    let onSave: (ANMedicationConcept) -> Void
    let onCancel: () -> Void

    init(medication: ANMedicationConcept?, onSave: @escaping (ANMedicationConcept) -> Void, onCancel: @escaping () -> Void) {
        self.medication = medication
        _clinicalName = State(initialValue: medication?.clinicalName ?? "")
        _nickname = State(initialValue: medication?.nickname ?? "")
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Medication Info")) {
                    TextField("Clinical Name", text: $clinicalName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Nickname", text: $nickname)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(medication == nil ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = ANMedicationConcept(
                            id: medication?.id ?? UUID(),
                            clinicalName: clinicalName.trimmingCharacters(in: .whitespacesAndNewlines),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(updated)
                    }
                    .disabled(clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    MedicationEditView(medication: nil, onSave: { _ in }, onCancel: {})
}

#Preview("Edit Existing Medication") {
    MedicationEditView(
        medication: ANMedicationConcept(
            id: UUID(),
            clinicalName: "Lisinopril",
            nickname: "Lisi"
        ),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Add New Medication") {
    MedicationEditView(medication: nil, onSave: { _ in }, onCancel: {})
}

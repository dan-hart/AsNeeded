// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit
// Removed search; no RxNorm import needed here.

struct MedicationEditView: View {
    @StateObject private var viewModel: MedicationEditViewModel
    
    let medication: ANMedicationConcept?
    let onSave: (ANMedicationConcept) -> Void
    let onCancel: () -> Void

    init(
        medication: ANMedicationConcept?,
        onSave: @escaping (ANMedicationConcept) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.medication = medication
        _viewModel = StateObject(wrappedValue: MedicationEditViewModel(medication: medication))
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private var lastRefillDateBinding: Binding<Date> {
        Binding<Date>(
            get: { viewModel.lastRefillDate ?? .now },
            set: { viewModel.lastRefillDate = $0 }
        )
    }
    private var nextRefillDateBinding: Binding<Date> {
        Binding<Date>(
            get: { viewModel.nextRefillDate ?? .now },
            set: { viewModel.nextRefillDate = $0 }
        )
    }

    private var isFormValid: Bool { viewModel.isFormValid }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Medication Info")) {
                    TextField("Clinical Name", text: $viewModel.clinicalName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Nickname", text: $viewModel.nickname)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                // Search suggestions removed
                
                Section(header: Text("Refill Info")) {
                    TextField("Quantity", text: $viewModel.quantityText)
                        .keyboardType(.decimalPad)
                    
                    DatePicker(
                        "Last Refill",
                        selection: lastRefillDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    DatePicker(
                        "Next Refill",
                        selection: nextRefillDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                Section(header: Text("Prescribed Dose")) {
                    TextField("Amount", text: $viewModel.prescribedDoseText)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $viewModel.prescribedUnit) {
                        Text("None").tag(Optional<ANUnitConcept>.none)
                        ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(Optional(unit))
                        }
                    }
                }
            }
            .navigationTitle(medication == nil ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = viewModel.buildMedication()
                        onSave(updated)
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
        // No-op: search removed
    }
}

#Preview {
    MedicationEditView(
        medication: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Edit Existing Medication") {
    MedicationEditView(
        medication: ANMedicationConcept(
            id: UUID(),
            clinicalName: "Lisinopril",
            nickname: "Lisi",
            quantity: 30,
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())
        ),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Add New Medication") {
    MedicationEditView(
        medication: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

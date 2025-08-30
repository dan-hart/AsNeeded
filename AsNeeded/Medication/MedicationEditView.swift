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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clinical Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Official medication name (e.g., Lisinopril)", text: $viewModel.clinicalName)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nickname (Optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Personal name for easy identification", text: $viewModel.nickname)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                // Search suggestions removed
                
                Section(header: Text("Refill Info")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Quantity")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("How many pills, mL, etc. you have", text: $viewModel.quantityText)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Button("-30") {
                            let currentDate = viewModel.lastRefillDate ?? .now
                            viewModel.lastRefillDate = Calendar.current.date(byAdding: .day, value: -30, to: currentDate)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        DatePicker(
                            "Last Refill",
                            selection: lastRefillDateBinding,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        
                        Button("+30") {
                            let currentDate = viewModel.lastRefillDate ?? .now
                            viewModel.lastRefillDate = Calendar.current.date(byAdding: .day, value: 30, to: currentDate)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Button("-30") {
                            let currentDate = viewModel.nextRefillDate ?? .now
                            viewModel.nextRefillDate = Calendar.current.date(byAdding: .day, value: -30, to: currentDate)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        DatePicker(
                            "Next Refill",
                            selection: nextRefillDateBinding,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        
                        Button("+30") {
                            let currentDate = viewModel.nextRefillDate ?? .now
                            viewModel.nextRefillDate = Calendar.current.date(byAdding: .day, value: 30, to: currentDate)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Section(header: Text("Prescribed Dose")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dose Amount")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("How much per dose (e.g., 5, 10, 0.5)", text: $viewModel.prescribedDoseText)
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dose Unit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Unit type (mg, mL, tablets, etc.)", selection: $viewModel.prescribedUnit) {
                            Text("None").tag(Optional<ANUnitConcept>.none)
                            ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(Optional(unit))
                            }
                        }
                    }
                }
                
                Section {
                    Button("Save") {
                        let updated = viewModel.buildMedication()
                        onSave(updated)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!viewModel.isFormValid)
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

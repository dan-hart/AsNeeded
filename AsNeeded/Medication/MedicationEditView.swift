// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit

struct MedicationEditView: View {
    @State private var clinicalName: String
    @State private var nickname: String
    @State private var quantityText: String
    @State private var lastRefillDate: Date?
    @State private var nextRefillDate: Date?
    @State private var prescribedDoseText: String
    @State private var prescribedUnit: ANUnitConcept?
    
    let medication: ANMedicationConcept?
    let onSave: (ANMedicationConcept) -> Void
    let onCancel: () -> Void

    init(
        medication: ANMedicationConcept?,
        onSave: @escaping (ANMedicationConcept) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.medication = medication
        _clinicalName = State(initialValue: medication?.clinicalName ?? "")
        _nickname = State(initialValue: medication?.nickname ?? "")
        if let quantity = medication?.quantity {
            _quantityText = State(initialValue: String(describing: quantity))
        } else {
            _quantityText = State(initialValue: "")
        }
        _lastRefillDate = State(initialValue: medication?.lastRefillDate)
        _nextRefillDate = State(initialValue: medication?.nextRefillDate)
        _prescribedDoseText = State(initialValue: medication?.prescribedDoseAmount.map { String(describing: $0) } ?? "")
        _prescribedUnit = State(initialValue: medication?.prescribedUnit)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private var lastRefillDateBinding: Binding<Date> {
        Binding<Date>(
            get: { lastRefillDate ?? .now },
            set: { lastRefillDate = $0 }
        )
    }
    private var nextRefillDateBinding: Binding<Date> {
        Binding<Date>(
            get: { nextRefillDate ?? .now },
            set: { nextRefillDate = $0 }
        )
    }

    private var isFormValid: Bool {
        let nameOK = !clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if doseText.isEmpty && prescribedUnit == nil { return nameOK }
        guard let amount = Double(doseText), amount > 0 else { return false }
        return nameOK && prescribedUnit != nil
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
                
                Section(header: Text("Refill Info")) {
                    TextField("Quantity", text: $quantityText)
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
                    TextField("Amount", text: $prescribedDoseText)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $prescribedUnit) {
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
                        let quantity = Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
                        let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let amount = (Double(doseText).flatMap { $0 > 0 ? $0 : nil })
                        let unit = (amount != nil) ? prescribedUnit : nil
                        let updated = ANMedicationConcept(
                            id: medication?.id ?? UUID(),
                            clinicalName: clinicalName.trimmingCharacters(in: .whitespacesAndNewlines),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity: quantity,
                            lastRefillDate: lastRefillDate,
                            nextRefillDate: nextRefillDate,
                            prescribedUnit: unit,
                            prescribedDoseAmount: amount
                        )
                        onSave(updated)
                    }
                    .disabled(!isFormValid)
                }
            }
        }
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

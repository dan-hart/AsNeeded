// LogDoseView.swift
// SwiftUI view for logging a dose taken for a medication, using ANModelKit concepts.

import SwiftUI
import ANModelKit

struct LogDoseView: View {
    let medication: ANMedicationConcept
    var onLog: (ANDoseConcept, ANEventConcept) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: Double = 1
    @State private var selectedUnit: ANUnitConcept = .unit
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dose")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Stepper(value: $amount, in: 0.5...100, step: 0.5) {
                            Text("\(amount, specifier: "%.1f")")
                        }
                    }
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Log Dose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        let dose = ANDoseConcept(amount: amount, unit: selectedUnit)
                        let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose)
                        onLog(dose, event)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

#if DEBUG
import SwiftUI
#Preview {
    LogDoseView(
        medication: ANMedicationConcept(clinicalName: "Ibuprofen", nickname: "Ibuprofen"),
        onLog: { _, _ in }
    )
}
#endif

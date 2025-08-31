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
	@State private var selectedDate: Date = .now

	init(
		medication: ANMedicationConcept,
		onLog: @escaping (ANDoseConcept, ANEventConcept) -> Void
	) {
		self.medication = medication
		self.onLog = onLog
		_amount = State(initialValue: medication.prescribedDoseAmount ?? 1)
		_selectedUnit = State(initialValue: medication.prescribedUnit ?? .unit)
	}
	
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

				Section(header: Text("When")) {
					DatePicker(
						"Date & Time",
						selection: $selectedDate,
						displayedComponents: [.date, .hourAndMinute]
					)
					.datePickerStyle(.compact)
					HStack {
						Spacer()
						Button("Set to Now") { selectedDate = .now }
							.buttonStyle(.bordered)
						Spacer().frame(width: 0)
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
						let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: selectedDate)
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

// LogDoseView.swift
// SwiftUI view for logging a dose taken for a medication, using ANModelKit concepts.

import SwiftUI
import ANModelKit
import SFSafeSymbols

struct LogDoseView: View {
	let medication: ANMedicationConcept
	var onLog: (ANDoseConcept, ANEventConcept) -> Void
	@Environment(\.dismiss) private var dismiss
	
	@State private var amount: Double = 1
	@State private var selectedUnit: ANUnitConcept = .unit
	@State private var selectedDate: Date = .now
	@State private var note: String = ""
	@FocusState private var isNoteFocused: Bool

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
				
				Section(header: Text("Note (Optional)")) {
					TextField("Add a note about this dose", text: $note, axis: .vertical)
						.lineLimit(3...6)
						.focused($isNoteFocused)
				}
			}
			.navigationTitle("Log Dose")
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(action: { dismiss() }) {
						Image(systemSymbol: .xmark)
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(action: {
						let dose = ANDoseConcept(amount: amount, unit: selectedUnit)
						let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
						let event = ANEventConcept(
							eventType: .doseTaken,
							medication: medication,
							dose: dose,
							date: selectedDate,
							note: trimmedNote.isEmpty ? nil : trimmedNote
						)
						onLog(dose, event)
						dismiss()
					}) {
						Image(systemSymbol: .checkmark)
							.bold()
					}
					.tint(.accentColor)
					.buttonStyle(.borderedProminent)
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

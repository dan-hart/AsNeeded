// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit

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
	
	private func hideKeyboard() {
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	}
	
	var body: some View {
		NavigationStack {
			Form {
				Section(header: Text("Medication Info"), footer: Text("Fields marked with * are required")) {
					VStack(alignment: .leading, spacing: 8) {
						HStack(spacing: 2) {
							Text("Clinical Name")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("*")
								.font(.subheadline)
								.foregroundStyle(.red)
						}
						
						EnhancedMedicationSearchField(
							text: $viewModel.clinicalName,
							placeholder: "Search for medication...",
							onMedicationSelected: { clinicalName, nickname in
								viewModel.clinicalName = clinicalName
								viewModel.nickname = nickname
							}
						)
					}
					
					VStack(alignment: .leading, spacing: 4) {
						HStack {
							Text("Nickname")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("(Optional)")
								.font(.caption)
								.foregroundStyle(.tertiary)
						}
						TextField("Personal name for easy identification", text: $viewModel.nickname)
							.autocapitalization(.words)
							.disableAutocorrection(true)
					}
				}
				
				Section(header: Text("Refill Info")) {
					VStack(alignment: .leading, spacing: 4) {
						HStack {
							Text("Current Quantity")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("(Optional)")
								.font(.caption)
								.foregroundStyle(.tertiary)
						}
						TextField("How many pills, mL, etc. you have", text: $viewModel.quantityText)
							.keyboardType(.decimalPad)
					}
					
					VStack(alignment: .leading, spacing: 4) {
						HStack {
							Text("Last Refill Date")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("(Optional)")
								.font(.caption)
								.foregroundStyle(.tertiary)
						}
						
						HStack {
							Button("-30d") {
								let currentDate = viewModel.lastRefillDate ?? .now
								viewModel.lastRefillDate = Calendar.current.date(byAdding: .day, value: -30, to: currentDate)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Subtract 30 days from last refill date")
							
							DatePicker(
								"",
								selection: lastRefillDateBinding,
								in: ...Date(), // Cannot select future dates
								displayedComponents: .date
							)
							.datePickerStyle(.compact)
							.labelsHidden()
							
							Button("+30d") {
								let currentDate = viewModel.lastRefillDate ?? .now
								viewModel.lastRefillDate = Calendar.current.date(byAdding: .day, value: 30, to: currentDate)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Add 30 days to last refill date")
						}
						
						Button("Reset") {
							viewModel.lastRefillDate = nil
						}
						.buttonStyle(.borderless)
						.controlSize(.small)
						.foregroundColor(.red)
						
						if let lastRefill = viewModel.lastRefillDate, lastRefill > Date() {
							Text("Last refill date cannot be in the future")
								.font(.caption)
								.foregroundColor(.red)
						}
					}
					
					VStack(alignment: .leading, spacing: 4) {
						HStack {
							Text("Next Refill Date")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("(Optional)")
								.font(.caption)
								.foregroundStyle(.tertiary)
						}
						
						HStack {
							Button("-30d") {
								let currentDate = viewModel.nextRefillDate ?? .now
								viewModel.nextRefillDate = Calendar.current.date(byAdding: .day, value: -30, to: currentDate)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Subtract 30 days from next refill date")
							
							DatePicker(
								"",
								selection: nextRefillDateBinding,
								in: Date()..., // Cannot select past dates
								displayedComponents: .date
							)
							.datePickerStyle(.compact)
							.labelsHidden()
							
							Button("+30d") {
								let currentDate = viewModel.nextRefillDate ?? .now
								viewModel.nextRefillDate = Calendar.current.date(byAdding: .day, value: 30, to: currentDate)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
							.accessibilityLabel("Add 30 days to next refill date")
						}
						
						Button("Reset") {
							viewModel.nextRefillDate = nil
						}
						.buttonStyle(.borderless)
						.controlSize(.small)
						.foregroundColor(.red)
						
						if let nextRefill = viewModel.nextRefillDate, nextRefill < Calendar.current.startOfDay(for: Date()) {
							Text("Next refill date cannot be in the past")
								.font(.caption)
								.foregroundColor(.red)
						}
					}
				}

				Section(header: Text("Prescribed Dose")) {
					VStack(alignment: .leading, spacing: 4) {
						HStack(spacing: 2) {
							Text("Dose Amount")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							if !viewModel.prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.prescribedUnit != nil {
								Text("*")
									.font(.subheadline)
									.foregroundStyle(.red)
							}
						}
						TextField("How much per dose (e.g., 5, 10, 0.5)", text: $viewModel.prescribedDoseText)
							.keyboardType(.decimalPad)
					}
					
					VStack(alignment: .leading, spacing: 4) {
						HStack(spacing: 2) {
							Text("Dose Unit")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							if !viewModel.prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.prescribedUnit != nil {
								Text("*")
									.font(.subheadline)
									.foregroundStyle(.red)
							}
						}
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

// MedicationEditViewModel.swift
// View model for MedicationEditView: handles RxNorm suggestions, validation, and model building.

import Foundation
import ANModelKit
// Removed RxNorm search; VM now only handles form + validation.

@MainActor
final class MedicationEditViewModel: ObservableObject {
	// Form fields
	@Published var clinicalName: String
	@Published var nickname: String
	@Published var quantityText: String
	@Published var lastRefillDate: Date?
	@Published var nextRefillDate: Date?
	@Published var prescribedDoseText: String
	@Published var prescribedUnit: ANUnitConcept?

	// Editing existing or adding new
	private let existingID: UUID?

	init(medication: ANMedicationConcept?) {
		self.existingID = medication?.id
		self.clinicalName = medication?.clinicalName ?? ""
		self.nickname = medication?.nickname ?? ""
		self.quantityText = medication?.quantity.map { String(describing: $0) } ?? ""
		self.lastRefillDate = medication?.lastRefillDate
		self.nextRefillDate = medication?.nextRefillDate
		self.prescribedDoseText = medication?.prescribedDoseAmount.map { String(describing: $0) } ?? ""
		self.prescribedUnit = medication?.prescribedUnit
	}

	var isFormValid: Bool {
		let nameOK = !clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
		if doseText.isEmpty && prescribedUnit == nil { return nameOK }
		guard let amount = Double(doseText), amount > 0 else { return false }
		return nameOK && prescribedUnit != nil
	}

	func buildMedication() -> ANMedicationConcept {
		let quantity = Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
		let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
		let amount = (Double(doseText).flatMap { $0 > 0 ? $0 : nil })
		let unit = (amount != nil) ? prescribedUnit : nil
		return ANMedicationConcept(
			id: existingID ?? UUID(),
			clinicalName: clinicalName.trimmingCharacters(in: .whitespacesAndNewlines),
			nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
			quantity: quantity,
			lastRefillDate: lastRefillDate,
			nextRefillDate: nextRefillDate,
			prescribedUnit: unit,
			prescribedDoseAmount: amount
		)
	}

}

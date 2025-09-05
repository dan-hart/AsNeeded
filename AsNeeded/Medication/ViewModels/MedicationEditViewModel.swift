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
		// Set default dates if not editing existing medication
		if let medication = medication {
			self.lastRefillDate = medication.lastRefillDate
			self.nextRefillDate = medication.nextRefillDate
		} else {
			// Default: last refill 30 days ago, next refill 30 days from now
			self.lastRefillDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
			self.nextRefillDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
		}
		self.prescribedDoseText = medication?.prescribedDoseAmount.map { String(describing: $0) } ?? ""
		self.prescribedUnit = medication?.prescribedUnit
	}

	var isFormValid: Bool {
		let nameOK = !clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Validate date logic: last refill can't be future, next refill can't be past
		if let lastRefill = lastRefillDate, lastRefill > Date() {
			return false // Last refill date cannot be in the future
		}
		if let nextRefill = nextRefillDate, nextRefill < Calendar.current.startOfDay(for: Date()) {
			return false // Next refill date cannot be in the past (allowing today)
		}
		
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

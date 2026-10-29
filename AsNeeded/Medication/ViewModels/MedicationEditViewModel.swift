// MedicationEditViewModel.swift
// View model for MedicationEditView: handles RxNorm suggestions, validation, and model building.

import ANModelKit
import Foundation
import SwiftUI

// Removed RxNorm search; VM now only handles form + validation.

@MainActor
final class MedicationEditViewModel: ObservableObject {
	// The presenting view owns this session so adaptive sheet rehosting keeps the draft.
	@MainActor
	final class Session: ObservableObject {
		private var medicationID: UUID?
		private var retainedDraft: MedicationEditViewModel?

		func draft(for medication: ANMedicationConcept?) -> MedicationEditViewModel {
			if let retainedDraft, medicationID == medication?.id { return retainedDraft }
			let draft = MedicationEditViewModel(medication: medication)
			medicationID = medication?.id
			retainedDraft = draft
			return draft
		}

		func reset() {
			retainedDraft = nil
			medicationID = nil
		}
	}

	var originalDraft: [String]?
	@Published private(set) var isSaving = false
	@Published var showingSaveError = false
	// Form fields
	@Published var clinicalName: String
	@Published var nickname: String
	@Published var initialQuantityText: String
	@Published var quantityText: String
	@Published var lastRefillDate: Date?
	@Published var nextRefillDate: Date?
	@Published var prescribedDoseText: String
	@Published var prescribedUnit: ANUnitConcept?
	@Published var displayColorHex: String?
	@Published var displaySymbol: String?
	@Published var isArchived: Bool
	@Published var nextDoseNotificationEnabled: Bool
	@Published var minimumHoursBetweenDosesText: String
	@Published var cautionHoursBetweenDosesText: String
	@Published var maxDailyAmountText: String
	@Published var lowStockThresholdText: String
	@Published var duplicateDoseWindowMinutes: Int
	@Published var refillLeadDays: Int

	// Editing existing or adding new
	let originalMedication: ANMedicationConcept?
	private let safetyProfileStore: MedicationSafetyProfileStore

	init(
		medication: ANMedicationConcept?,
		safetyProfileStore: MedicationSafetyProfileStore = .shared
	) {
		self.safetyProfileStore = safetyProfileStore
		originalMedication = medication
		clinicalName = medication?.clinicalName ?? ""
		nickname = medication?.nickname ?? ""
		initialQuantityText = medication?.initialQuantity.map { String(describing: $0) } ?? ""
		quantityText = medication?.quantity.map { String(describing: $0) } ?? ""
		// Set dates from existing medication or nil for new medication
		if let medication = medication {
			lastRefillDate = medication.lastRefillDate
			nextRefillDate = medication.nextRefillDate
		} else {
			lastRefillDate = nil
			nextRefillDate = nil
		}
		prescribedDoseText = medication?.prescribedDoseAmount.map { String(describing: $0) } ?? ""
		prescribedUnit = medication?.prescribedUnit
		displayColorHex = medication?.displayColorHex
		displaySymbol = medication?.symbolInfo?.name
		isArchived = medication?.isArchived ?? false

		let safetyProfile = medication.map { safetyProfileStore.profile(for: $0.id) } ?? .empty
		nextDoseNotificationEnabled = medication?.nextDoseNotificationEnabled ?? false
		minimumHoursBetweenDosesText = (medication?.minimumHoursBetweenDoses ?? safetyProfile.minimumHoursBetweenDoses).map { String(describing: $0) } ?? ""
		cautionHoursBetweenDosesText = safetyProfile.cautionHoursBetweenDoses.map { String(describing: $0) } ?? ""
		maxDailyAmountText = (medication?.maximumDailyDoseAmount ?? safetyProfile.maxDailyAmount).map { String(describing: $0) } ?? ""
		lowStockThresholdText = safetyProfile.lowStockThreshold.map { String(describing: $0) } ?? ""
		duplicateDoseWindowMinutes = safetyProfile.duplicateDoseWindowMinutes
		refillLeadDays = safetyProfile.refillLeadDays
	}

	// Computed property for display color
	var displayColor: Color {
		if let hex = displayColorHex, let color = Color(hex: hex) {
			return color
		}
		return .accent
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

		guard stockValidationMessage == nil, doseLimitValidationMessage == nil else { return false }
		if doseText.isEmpty && prescribedUnit == nil { return nameOK }
		guard let amount = Double(doseText), amount.isFinite, amount > 0 else { return false }
		return nameOK && prescribedUnit != nil
	}

	var stockValidationMessage: String? {
		for (text, label) in [
			(quantityText, "Current stock"),
			(initialQuantityText, "Refill quantity")
		] {
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			guard let value = Double(trimmed), value.isFinite, value >= 0 else {
				return "\(label) must be zero or a positive, finite number. Leave it blank if unknown."
			}
		}
		return nil
	}

	var doseLimitValidationMessage: String? {
		for (text, label) in [
			(minimumHoursBetweenDosesText, "Minimum hours between doses"),
			(maxDailyAmountText, "Maximum amount in 24 hours")
		] {
			if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
			   normalizedNumber(from: text) == nil {
				return "\(label) must be a positive, finite number."
			}
		}
		if let maximum = normalizedNumber(from: maxDailyAmountText) {
			guard let dose = normalizedNumber(from: prescribedDoseText), prescribedUnit != nil else {
				return "Add a prescribed dose and unit to use a maximum amount in 24 hours."
			}
			if dose > maximum {
				return "The prescribed dose cannot exceed the maximum amount in 24 hours."
			}
		}
		return nil
	}

	func buildMedication() -> ANMedicationConcept {
		let initialQuantity = Double(initialQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
		let quantity = Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
		let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
		let amount = (Double(doseText).flatMap { $0.isFinite && $0 > 0 ? $0 : nil })
		let unit = (amount != nil) ? prescribedUnit : nil
		var medication = originalMedication ?? ANMedicationConcept(clinicalName: "")
		medication.clinicalName = clinicalName.trimmingCharacters(in: .whitespacesAndNewlines)
		medication.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		medication.quantity = quantity
		medication.initialQuantity = initialQuantity
		medication.lastRefillDate = lastRefillDate
		medication.nextRefillDate = nextRefillDate
		medication.prescribedUnit = unit
		medication.prescribedDoseAmount = amount
		medication.minimumHoursBetweenDoses = normalizedNumber(from: minimumHoursBetweenDosesText)
		medication.maximumDailyDoseAmount = normalizedNumber(from: maxDailyAmountText)
		medication.nextDoseNotificationEnabled = nextDoseNotificationEnabled
		medication.displayColorHex = displayColorHex
		if medication.symbolInfo?.name != displaySymbol {
			medication.symbolInfo = ANMedicationConcept.createSymbolInfo(from: displaySymbol)
		}
		medication.isArchived = isArchived
		return medication
	}

	func buildSafetyProfile() -> MedicationSafetyProfile {
		MedicationSafetyProfile(
			cautionHoursBetweenDoses: normalizedNumber(from: cautionHoursBetweenDosesText),
			duplicateDoseWindowMinutes: max(5, duplicateDoseWindowMinutes),
			lowStockThreshold: normalizedNumber(from: lowStockThresholdText),
			refillLeadDays: max(1, refillLeadDays)
		)
	}

	func saveMedication(using persist: (ANMedicationConcept) async -> Bool) async -> Bool {
		guard !isSaving, isFormValid else { return false }
		isSaving = true
		defer { isSaving = false }
		let updated = buildMedication()
		let profile = buildSafetyProfile()
		guard await persist(updated) else { return false }
		safetyProfileStore.save(profile, for: updated.id)
		return true
	}

	func saveSafetyProfile(for medicationID: UUID) {
		safetyProfileStore.save(buildSafetyProfile(), for: medicationID)
	}

	private func normalizedNumber(from text: String) -> Double? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let value = Double(trimmed), value.isFinite, value > 0 else {
			return nil
		}

		return value
	}
}

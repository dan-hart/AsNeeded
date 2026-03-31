// MedicationEditViewModel.swift
// View model for MedicationEditView: handles RxNorm suggestions, validation, and model building.

import ANModelKit
import Foundation
import SwiftUI

// Removed RxNorm search; VM now only handles form + validation.

@MainActor
final class MedicationEditViewModel: ObservableObject {
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
    @Published var minimumHoursBetweenDosesText: String
    @Published var cautionHoursBetweenDosesText: String
    @Published var maxDailyAmountText: String
    @Published var lowStockThresholdText: String
    @Published var duplicateDoseWindowMinutes: Int
    @Published var refillLeadDays: Int

    // Editing existing or adding new
    private let existingID: UUID?
    private let safetyProfileStore: MedicationSafetyProfileStore

    init(
        medication: ANMedicationConcept?,
        safetyProfileStore: MedicationSafetyProfileStore = .shared
    ) {
        self.safetyProfileStore = safetyProfileStore
        existingID = medication?.id
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
        minimumHoursBetweenDosesText = safetyProfile.minimumHoursBetweenDoses.map { String(describing: $0) } ?? ""
        cautionHoursBetweenDosesText = safetyProfile.cautionHoursBetweenDoses.map { String(describing: $0) } ?? ""
        maxDailyAmountText = safetyProfile.maxDailyAmount.map { String(describing: $0) } ?? ""
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

        if doseText.isEmpty && prescribedUnit == nil { return nameOK }
        guard let amount = Double(doseText), amount > 0 else { return false }
        return nameOK && prescribedUnit != nil
    }

    func buildMedication() -> ANMedicationConcept {
        let initialQuantity = Double(initialQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
        let quantity = Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
        let doseText = prescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = (Double(doseText).flatMap { $0 > 0 ? $0 : nil })
        let unit = (amount != nil) ? prescribedUnit : nil
        var medication = ANMedicationConcept(
            id: existingID ?? UUID(),
            clinicalName: clinicalName.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            initialQuantity: initialQuantity,
            lastRefillDate: lastRefillDate,
            nextRefillDate: nextRefillDate,
            prescribedUnit: unit,
            prescribedDoseAmount: amount
        )
        medication.displayColorHex = displayColorHex
        medication.symbolInfo = ANMedicationConcept.createSymbolInfo(from: displaySymbol)
        medication.isArchived = isArchived
        return medication
    }

    func buildSafetyProfile() -> MedicationSafetyProfile {
        MedicationSafetyProfile(
            minimumHoursBetweenDoses: normalizedNumber(from: minimumHoursBetweenDosesText),
            cautionHoursBetweenDoses: normalizedNumber(from: cautionHoursBetweenDosesText),
            maxDailyAmount: normalizedNumber(from: maxDailyAmountText),
            duplicateDoseWindowMinutes: max(5, duplicateDoseWindowMinutes),
            lowStockThreshold: normalizedNumber(from: lowStockThresholdText),
            refillLeadDays: max(1, refillLeadDays)
        )
    }

    func saveSafetyProfile(for medicationID: UUID) {
        safetyProfileStore.save(buildSafetyProfile(), for: medicationID)
    }

    private func normalizedNumber(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            return nil
        }

        return value
    }
}

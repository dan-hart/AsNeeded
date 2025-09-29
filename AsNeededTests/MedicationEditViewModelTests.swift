// MedicationEditViewModelTests.swift
// Comprehensive unit tests for MedicationEditViewModel

import Testing
import Foundation
@testable import AsNeeded
import ANModelKit

@Suite("MedicationEditViewModel Tests", .tags(.medication, .viewModel, .edit, .unit))
struct MedicationEditViewModelTests {
	
	// MARK: - Initialization Tests
	
	@Test("Initialize with nil medication creates new medication")
	@MainActor
	func testInitWithNilMedication() {
		let viewModel = MedicationEditViewModel(medication: nil)
		
		#expect(viewModel.clinicalName == "")
		#expect(viewModel.nickname == "")
		#expect(viewModel.quantityText == "")
		#expect(viewModel.prescribedDoseText == "")
		#expect(viewModel.prescribedUnit == nil)
		#expect(viewModel.lastRefillDate == nil)
		#expect(viewModel.nextRefillDate == nil)
	}
	
	@Test("Initialize with existing medication populates fields")
	@MainActor
	func testInitWithExistingMedication() {
		let lastRefill = Date().addingTimeInterval(-86400 * 7) // 7 days ago
		let nextRefill = Date().addingTimeInterval(86400 * 23) // 23 days from now
		
		let medication = ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: "Pain Relief",
			quantity: 100,
			lastRefillDate: lastRefill,
			nextRefillDate: nextRefill,
			prescribedUnit: .milligram,
			prescribedDoseAmount: 200
		)
		
		let viewModel = MedicationEditViewModel(medication: medication)
		
		#expect(viewModel.clinicalName == "Ibuprofen")
		#expect(viewModel.nickname == "Pain Relief")
		#expect(viewModel.quantityText == "100.0")
		#expect(viewModel.prescribedDoseText == "200.0")
		#expect(viewModel.prescribedUnit == .milligram)
		#expect(viewModel.lastRefillDate == lastRefill)
		#expect(viewModel.nextRefillDate == nextRefill)
	}
	
	// MARK: - Form Validation Tests
	
	@Test("Form valid with minimal required fields")
	@MainActor
	func testFormValidMinimal() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Aspirin"
		
		#expect(viewModel.isFormValid == true)
	}
	
	@Test("Form invalid with empty clinical name")
	@MainActor
	func testFormInvalidEmptyName() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = ""
		
		#expect(viewModel.isFormValid == false)
		
		// Also test with whitespace only
		viewModel.clinicalName = "   "
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form valid with dose and unit")
	@MainActor
	func testFormValidWithDose() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "100"
		viewModel.prescribedUnit = .milligram
		
		#expect(viewModel.isFormValid == true)
	}
	
	@Test("Form invalid with dose but no unit")
	@MainActor
	func testFormInvalidDoseNoUnit() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "100"
		viewModel.prescribedUnit = nil
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with unit but no dose")
	@MainActor
	func testFormInvalidUnitNoDose() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = ""
		viewModel.prescribedUnit = .milligram
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with negative dose")
	@MainActor
	func testFormInvalidNegativeDose() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "-10"
		viewModel.prescribedUnit = .milligram
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with zero dose")
	@MainActor
	func testFormInvalidZeroDose() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "0"
		viewModel.prescribedUnit = .milligram
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with non-numeric dose")
	@MainActor
	func testFormInvalidNonNumericDose() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "abc"
		viewModel.prescribedUnit = .milligram
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with future last refill date")
	@MainActor
	func testFormInvalidFutureLastRefill() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.lastRefillDate = Date().addingTimeInterval(86400) // Tomorrow
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form invalid with past next refill date")
	@MainActor
	func testFormInvalidPastNextRefill() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.nextRefillDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) // 2 days ago
		
		#expect(viewModel.isFormValid == false)
	}
	
	@Test("Form valid with today as next refill date")
	@MainActor
	func testFormValidTodayNextRefill() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.nextRefillDate = Calendar.current.startOfDay(for: Date()) // Today
		
		#expect(viewModel.isFormValid == true)
	}
	
	// MARK: - Build Medication Tests
	
	@Test("Build medication with all fields")
	@MainActor
	func testBuildMedicationAllFields() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "  Ibuprofen  " // With whitespace
		viewModel.nickname = "  Pain Relief  "
		viewModel.quantityText = "100"
		viewModel.prescribedDoseText = "200"
		viewModel.prescribedUnit = .milligram
		
		let lastRefill = Date().addingTimeInterval(-86400)
		let nextRefill = Date().addingTimeInterval(86400)
		viewModel.lastRefillDate = lastRefill
		viewModel.nextRefillDate = nextRefill
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.clinicalName == "Ibuprofen") // Trimmed
		#expect(medication.nickname == "Pain Relief") // Trimmed
		#expect(medication.quantity == 100)
		#expect(medication.prescribedDoseAmount == 200)
		#expect(medication.prescribedUnit == .milligram)
		#expect(medication.lastRefillDate == lastRefill)
		#expect(medication.nextRefillDate == nextRefill)
	}
	
	@Test("Build medication with minimal fields")
	@MainActor
	func testBuildMedicationMinimalFields() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Aspirin"
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.clinicalName == "Aspirin")
		#expect(medication.nickname == "")
		#expect(medication.quantity == nil)
		#expect(medication.prescribedDoseAmount == nil)
		#expect(medication.prescribedUnit == nil)
	}
	
	@Test("Build medication preserves existing ID when editing")
	@MainActor
	func testBuildMedicationPreservesID() {
		let existingMedication = ANMedicationConcept(clinicalName: "Original")
		let originalID = existingMedication.id
		
		let viewModel = MedicationEditViewModel(medication: existingMedication)
		viewModel.clinicalName = "Updated"
		
		let updatedMedication = viewModel.buildMedication()
		
		#expect(updatedMedication.id == originalID)
		#expect(updatedMedication.clinicalName == "Updated")
	}
	
	@Test("Build medication creates new ID when adding")
	@MainActor
	func testBuildMedicationNewID() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "New Medication"
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.id != UUID()) // Should have a valid UUID
		#expect(medication.clinicalName == "New Medication")
	}
	
	@Test("Build medication handles invalid quantity")
	@MainActor
	func testBuildMedicationInvalidQuantity() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.quantityText = "invalid"
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.quantity == nil)
	}
	
	@Test("Build medication handles negative quantity")
	@MainActor
	func testBuildMedicationNegativeQuantity() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.quantityText = "-50"
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.quantity == -50) // Note: The model allows negative quantities
	}
	
	@Test("Build medication ignores unit when dose is invalid")
	@MainActor
	func testBuildMedicationInvalidDoseIgnoresUnit() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.prescribedDoseText = "invalid"
		viewModel.prescribedUnit = .milligram
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.prescribedDoseAmount == nil)
		#expect(medication.prescribedUnit == nil) // Unit is ignored when dose is invalid
	}
	
	// MARK: - Edge Cases
	
	@Test("Whitespace trimming in all text fields")
	@MainActor
	func testWhitespaceTrimming() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "\n\t Medication \n\t"
		viewModel.nickname = "  Nickname  "
		viewModel.quantityText = "  100  "
		viewModel.prescribedDoseText = "  200  "
		viewModel.prescribedUnit = .milligram
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.clinicalName == "Medication")
		#expect(medication.nickname == "Nickname")
		#expect(medication.quantity == 100)
		#expect(medication.prescribedDoseAmount == 200)
	}
	
	@Test("Empty nickname becomes empty string not nil")
	@MainActor
	func testEmptyNickname() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Medication"
		viewModel.nickname = ""
		
		let medication = viewModel.buildMedication()
		
		#expect(medication.nickname == "")
	}
	
	// MARK: - Performance Tests
	
	@Test("Form validation is performant")
	@MainActor
	func testFormValidationPerformance() {
		let viewModel = MedicationEditViewModel(medication: nil)
		
		let startTime = Date()
		for i in 0..<1000 {
			viewModel.clinicalName = "Med \(i)"
			viewModel.prescribedDoseText = "\(i)"
			viewModel.prescribedUnit = i % 2 == 0 ? .milligram : .microgram
			_ = viewModel.isFormValid
		}
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(elapsed < 0.5) // Should complete 1000 validations in less than 500ms
	}
	
	@Test("Build medication is performant")
	@MainActor
	func testBuildMedicationPerformance() {
		let viewModel = MedicationEditViewModel(medication: nil)
		viewModel.clinicalName = "Test Medication"
		viewModel.nickname = "Test"
		viewModel.quantityText = "100"
		viewModel.prescribedDoseText = "200"
		viewModel.prescribedUnit = .milligram
		
		let startTime = Date()
		for _ in 0..<1000 {
			_ = viewModel.buildMedication()
		}
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(elapsed < 0.5) // Should complete 1000 builds in less than 500ms
	}
}
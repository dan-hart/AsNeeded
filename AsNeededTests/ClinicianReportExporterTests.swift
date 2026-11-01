import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("ClinicianReportExporter Tests")
struct ClinicianReportExporterTests {
	private func makeMedication(
		name: String = "Ibuprofen",
		quantity: Double = 24,
		nextRefillDate: Date? = nil
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: name,
			nickname: nil,
			quantity: quantity,
			initialQuantity: 30,
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -10, to: .now),
			nextRefillDate: nextRefillDate,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
	}

	private func makeEvent(medication: ANMedicationConcept, daysAgo: Int, amount: Double = 2) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: .tablet),
			date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
		)
	}

	@Test("Build summary captures medication and refill details")
	func buildSummaryCapturesMedicationDetails() {
		let medication = makeMedication(nextRefillDate: Calendar.current.date(byAdding: .day, value: 2, to: .now))
		let events = [
			makeEvent(medication: medication, daysAgo: 1),
			makeEvent(medication: medication, daysAgo: 3),
			makeEvent(medication: medication, daysAgo: 8),
		]
		let exporter = ClinicianReportExporter()

		let summary = exporter.buildSummary(
			medications: [medication],
			events: events,
			safetyProfiles: [
				medication.id.uuidString: MedicationSafetyProfile(
					lowStockThreshold: 10,
					refillLeadDays: 5
				),
			]
		)

		#expect(summary.medicationCount == 1)
		#expect(summary.eventCount == 3)
		#expect(summary.medications.first?.name == medication.displayName)
		#expect(summary.medications.first?.logsInLast30Days == 3)
		#expect(summary.medications.first?.prescribedDose.contains("2") == true)
		#expect(summary.medications.first?.prescribedDose.contains("tab") == true)
		#expect(summary.medications.first?.refillStatus.contains("Next refill") == true)
	}

	@Test("PDF output is generated")
	func pdfOutputIsGenerated() {
		let medication = makeMedication()
		let exporter = ClinicianReportExporter()
		let summary = exporter.buildSummary(
			medications: [medication],
			events: [makeEvent(medication: medication, daysAgo: 0)]
		)

		let pdf = exporter.makePDF(summary: summary)

		#expect(pdf.count > 500)
		#expect(String(data: pdf.prefix(4), encoding: .utf8) == "%PDF")
	}
}

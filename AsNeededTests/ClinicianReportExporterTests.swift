import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("ClinicianReportExporter Tests")
struct ClinicianReportExporterTests {
	private func makeMedication(
		name: String = "Ibuprofen",
		quantity: Double = 24,
		nextRefillDate: Date? = nil,
		unit: ANUnitConcept? = .tablet
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: name,
			nickname: nil,
			quantity: quantity,
			initialQuantity: 30,
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -10, to: .now),
			nextRefillDate: nextRefillDate,
			prescribedUnit: unit,
			prescribedDoseAmount: 2
		)
	}

	private func makeEvent(
		medication: ANMedicationConcept,
		date: Date,
		amount: Double = 2,
		unit: ANUnitConcept = .tablet,
		eventType: ANEventType = .doseTaken
	) -> ANEventConcept {
		ANEventConcept(
			eventType: eventType,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: unit),
			date: date
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
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let medication = makeMedication(
			quantity: 24,
			nextRefillDate: Calendar.current.date(byAdding: .day, value: 8, to: generatedAt)
		)
		let events = [
			ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: 2, unit: .tablet),
				date: Calendar.current.date(byAdding: .day, value: -1, to: generatedAt) ?? generatedAt
			),
			ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: 2, unit: .tablet),
				date: Calendar.current.date(byAdding: .day, value: -3, to: generatedAt) ?? generatedAt
			),
			ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: 2, unit: .tablet),
				date: Calendar.current.date(byAdding: .day, value: -8, to: generatedAt) ?? generatedAt
			),
		]
		let exporter = ClinicianReportExporter()

		let summary = exporter.buildSummary(
			medications: [medication],
			events: events,
			refillProfiles: [
				medication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 25),
			],
			generatedAt: generatedAt
		)
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		let expectedLastLogged = formatter.string(from: events[0].date)

		#expect(summary.medicationCount == 1)
		#expect(summary.eventCount == 3)
		#expect(summary.medications.first?.name == medication.displayName)
		#expect(summary.medications.first?.logsInLast30Days == 3)
		#expect(summary.medications.first?.prescribedDose.contains("2") == true)
		#expect(summary.medications.first?.prescribedDose.contains("tab") == true)
		#expect(summary.medications.first?.quantityStatus == "24 tab remaining")
		#expect(summary.medications.first?.lastLogged == expectedLastLogged)
		#expect(summary.medications.first?.averageDailyUsage == "2 tab/day")
		#expect(summary.medications.first?.refillStatus.contains("Refill prep would be timely.") == true)
		#expect(summary.medications.first?.refillStatus.contains("Next refill") == true)
	}

	@Test("Summary excludes future doses and includes the exact 30-day boundary")
	func summaryBoundsDoseEventsByGenerationDate() {
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let medication = makeMedication()
		let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: generatedAt) ?? generatedAt
		let boundaryDate = Calendar.current.date(byAdding: .day, value: -30, to: generatedAt) ?? generatedAt
		let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: generatedAt) ?? generatedAt
		let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: generatedAt) ?? generatedAt
		let events = [
			makeEvent(medication: medication, date: futureDate, amount: 20),
			makeEvent(medication: medication, date: recentDate),
			makeEvent(medication: medication, date: boundaryDate),
			makeEvent(medication: medication, date: oldDate),
		]

		let summary = ClinicianReportExporter().buildSummary(
			medications: [medication],
			events: events,
			generatedAt: generatedAt
		)
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short

		#expect(summary.eventCount == 3)
		#expect(summary.medications.first?.logsInLast30Days == 2)
		#expect(summary.medications.first?.lastLogged == formatter.string(from: recentDate))
	}

	@Test("Summary preserves inferred homogeneous usage units")
	func summaryPreservesInferredUsageUnit() {
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let medication = makeMedication(unit: nil)
		let events = [
			makeEvent(
				medication: medication,
				date: Calendar.current.date(byAdding: .day, value: -2, to: generatedAt) ?? generatedAt,
				amount: 2,
				unit: .milliliter
			),
			makeEvent(
				medication: medication,
				date: Calendar.current.date(byAdding: .day, value: -1, to: generatedAt) ?? generatedAt,
				amount: 4,
				unit: .milliliter
			),
		]

		let summary = ClinicianReportExporter().buildSummary(
			medications: [medication],
			events: events,
			generatedAt: generatedAt
		)

		#expect(summary.medications.first?.averageDailyUsage == "3 \(ANUnitConcept.milliliter.abbreviation)/day")
	}

	@Test("Summary declines average usage for mixed inferred units")
	func summaryDeclinesMixedInferredUnits() {
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let medication = makeMedication(unit: nil)
		let eventDate = Calendar.current.date(byAdding: .day, value: -1, to: generatedAt) ?? generatedAt
		let events = [
			makeEvent(medication: medication, date: eventDate, amount: 2, unit: .tablet),
			makeEvent(medication: medication, date: eventDate, amount: 500, unit: .milligram),
		]

		let summary = ClinicianReportExporter().buildSummary(
			medications: [medication],
			events: events,
			generatedAt: generatedAt
		)

		#expect(summary.medications.first?.averageDailyUsage == "Not enough recent data")
	}

	@Test("Summary orders medications and applies default and custom refill thresholds")
	func summaryOrdersMedicationsAndAppliesThresholds() {
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let defaultThresholdMedication = makeMedication(name: "Zeta", quantity: 12)
		let customThresholdMedication = makeMedication(name: "Alpha", quantity: 12)

		let summary = ClinicianReportExporter().buildSummary(
			medications: [defaultThresholdMedication, customThresholdMedication],
			events: [],
			refillProfiles: [
				customThresholdMedication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 15),
			],
			generatedAt: generatedAt
		)

		#expect(summary.medications.map(\.name) == ["Alpha", "Zeta"])
		#expect(summary.medications[0].refillStatus == "Refill prep would be timely.")
		#expect(summary.medications[1].refillStatus == "Log more doses to estimate your run-out date.")
		#expect(summary.disclaimer == "This report summarizes self-logged medication history. It may be incomplete or incorrect and should not replace clinical judgment.")
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

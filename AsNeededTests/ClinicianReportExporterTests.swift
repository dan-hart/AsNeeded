import ANModelKit
@testable import AsNeeded
import Foundation
import PDFKit
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

	@Test("PDF content matches the clinician summary")
	func pdfContentMatchesSummary() throws {
		let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
		let disclaimer = "This report summarizes self-logged medication history. It may be incomplete or incorrect and should not replace clinical judgment."
		let summary = ClinicianReportSummary(
			generatedAt: generatedAt,
			medicationCount: 2,
			eventCount: 7,
			medications: [
				ClinicianMedicationSummary(
					name: "Alpha",
					prescribedDose: "1 tab",
					quantityStatus: "12 tab remaining",
					lastLogged: "Jan 10, 2027 at 9:30 AM",
					logsInLast30Days: 4,
					averageDailyUsage: "2 tab/day",
					refillStatus: "Refill prep would be timely."
				),
				ClinicianMedicationSummary(
					name: "Zeta",
					prescribedDose: "5 mg",
					quantityStatus: "20 mg remaining",
					lastLogged: "Jan 9, 2027 at 8:15 PM",
					logsInLast30Days: 3,
					averageDailyUsage: "5 mg/day",
					refillStatus: "About 4d of supply at your recent pace."
				),
			],
			disclaimer: disclaimer
		)
		let pdf = ClinicianReportExporter().makePDF(summary: summary)
		let document = try #require(PDFDocument(data: pdf))
		let extractedText = (0 ..< document.pageCount)
			.compactMap { document.page(at: $0)?.string }
			.joined(separator: "\n")
		func normalized(_ value: String) -> String {
			value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
		}
		let text = normalized(extractedText)
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		let alphaRange = try #require(text.range(of: "Alpha"))
		let zetaRange = try #require(text.range(of: "Zeta"))

		#expect(text.contains(normalized("Generated \(formatter.string(from: generatedAt))")))
		#expect(text.contains("Medications: 2"))
		#expect(text.contains("Dose logs: 7"))
		#expect(alphaRange.lowerBound < zetaRange.lowerBound)
		#expect(text.contains("Prescribed dose: 1 tab"))
		#expect(text.contains("Quantity: 12 tab remaining"))
		#expect(text.contains("Last logged: Jan 10, 2027 at 9:30 AM"))
		#expect(text.contains("Logs in last 30 days: 4"))
		#expect(text.contains("Average daily usage: 2 tab/day"))
		#expect(text.contains("Refill status: Refill prep would be timely."))
		#expect(text.contains("Prescribed dose: 5 mg"))
		#expect(text.contains("Quantity: 20 mg remaining"))
		#expect(text.contains("Last logged: Jan 9, 2027 at 8:15 PM"))
		#expect(text.contains("Logs in last 30 days: 3"))
		#expect(text.contains("Average daily usage: 5 mg/day"))
		#expect(text.contains("Refill status: About 4d of supply at your recent pace."))
		#expect(text.contains(normalized(disclaimer)))
	}
}

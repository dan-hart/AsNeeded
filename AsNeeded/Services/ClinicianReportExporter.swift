import ANModelKit
import Foundation
import UIKit

struct ClinicianMedicationSummary: Equatable {
	let name: String
	let prescribedDose: String
	let quantityStatus: String
	let lastLogged: String
	let logsInLast30Days: Int
	let averageDailyUsage: String
	let refillStatus: String
}

struct ClinicianReportSummary: Equatable {
	let generatedAt: Date
	let medicationCount: Int
	let eventCount: Int
	let medications: [ClinicianMedicationSummary]
	let disclaimer: String
}

struct ClinicianReportExporter {
	private let calendar: Calendar
	private let doseGuidanceService: MedicationDoseGuidanceService

	init(
		calendar: Calendar = .current,
		doseGuidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService()
	) {
		self.calendar = calendar
		self.doseGuidanceService = doseGuidanceService
	}

	func buildSummary(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		safetyProfiles: [String: MedicationSafetyProfile] = [:],
		generatedAt: Date = .now
	) -> ClinicianReportSummary {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short

		let summaries = medications
			.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
			.map { medication in
				let medicationEvents = events
					.filter { $0.eventType == .doseTaken && $0.medication?.id == medication.id }
					.sorted { $0.date > $1.date }
				let profile = safetyProfiles[medication.id.uuidString] ?? .empty
				let projection = doseGuidanceService.refillProjection(
					for: medication,
					at: generatedAt,
					events: events,
					profile: profile
				)
				let logsInLast30Days = medicationEvents.filter {
					$0.date >= (calendar.date(byAdding: .day, value: -30, to: generatedAt) ?? generatedAt)
				}.count
				let prescribedDose = {
					guard let amount = medication.prescribedDoseAmount,
					      let unit = medication.prescribedUnit
					else {
						return "Not saved"
					}
					return "\(amount.formattedAmount) \(unit.abbreviation)"
				}()
				let quantityStatus = {
					guard let quantity = medication.quantity else {
						return "Quantity not tracked"
					}

					if let unit = medication.prescribedUnit {
						return "\(quantity.formattedAmount) \(unit.abbreviation) remaining"
					}

					return "\(quantity.formattedAmount) remaining"
				}()
				let lastLogged = medicationEvents.first.map { formatter.string(from: $0.date) } ?? "No doses logged"
				let averageDailyUsage = {
					guard projection.averageDailyUsage > 0 else {
						return "Not enough recent data"
					}

					if let unit = medication.prescribedUnit {
						return "\(projection.averageDailyUsage.formattedAmount) \(unit.abbreviation)/day"
					}

					return "\(projection.averageDailyUsage.formattedAmount) per day"
				}()
				let refillStatus = {
					if let nextRefillDate = medication.nextRefillDate {
						return "\(projection.statusMessage) Next refill: \(formatter.string(from: nextRefillDate))"
					}

					return projection.statusMessage
				}()

				return ClinicianMedicationSummary(
					name: medication.displayName,
					prescribedDose: prescribedDose,
					quantityStatus: quantityStatus,
					lastLogged: lastLogged,
					logsInLast30Days: logsInLast30Days,
					averageDailyUsage: averageDailyUsage,
					refillStatus: refillStatus
				)
			}

		return ClinicianReportSummary(
			generatedAt: generatedAt,
			medicationCount: medications.count,
			eventCount: events.filter { $0.eventType == .doseTaken }.count,
			medications: summaries,
			disclaimer: "This report summarizes self-logged medication history. It may be incomplete or incorrect and should not replace clinical judgment."
		)
	}

	func makePDF(summary: ClinicianReportSummary) -> Data {
		let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))

		return renderer.pdfData { context in
			var lineY: CGFloat = 48
			let leftMargin: CGFloat = 44
			let rightMargin: CGFloat = 568
			let bodyWidth = rightMargin - leftMargin

			func startPageIfNeeded(for height: CGFloat) {
				if context.pdfContextBounds.maxY - lineY < height {
					context.beginPage()
					lineY = 48
				}
			}

			func draw(_ text: String, font: UIFont, color: UIColor = .label, spacingAfter: CGFloat = 10) {
				startPageIfNeeded(for: 48)
				let paragraph = NSMutableParagraphStyle()
				paragraph.lineBreakMode = .byWordWrapping
				let attributes: [NSAttributedString.Key: Any] = [
					.font: font,
					.foregroundColor: color,
					.paragraphStyle: paragraph,
				]
				let attributed = NSAttributedString(string: text, attributes: attributes)
				let rect = attributed.boundingRect(
					with: CGSize(width: bodyWidth, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					context: nil
				)
				startPageIfNeeded(for: rect.height + spacingAfter)
				attributed.draw(in: CGRect(x: leftMargin, y: lineY, width: bodyWidth, height: rect.height))
				lineY += rect.height + spacingAfter
			}

			context.beginPage()

			let generatedFormatter = DateFormatter()
			generatedFormatter.dateStyle = .medium
			generatedFormatter.timeStyle = .short

			draw("As Needed Clinician Summary", font: .boldSystemFont(ofSize: 22), spacingAfter: 6)
			draw("Generated \(generatedFormatter.string(from: summary.generatedAt))", font: .systemFont(ofSize: 12), color: .secondaryLabel, spacingAfter: 18)
			draw("Overview", font: .boldSystemFont(ofSize: 16), spacingAfter: 6)
			draw("Medications: \(summary.medicationCount)\nDose logs: \(summary.eventCount)", font: .systemFont(ofSize: 12), spacingAfter: 18)

			for medication in summary.medications {
				draw(medication.name, font: .boldSystemFont(ofSize: 15), spacingAfter: 4)
				draw("Prescribed dose: \(medication.prescribedDose)", font: .systemFont(ofSize: 12), spacingAfter: 4)
				draw("Quantity: \(medication.quantityStatus)", font: .systemFont(ofSize: 12), spacingAfter: 4)
				draw("Last logged: \(medication.lastLogged)", font: .systemFont(ofSize: 12), spacingAfter: 4)
				draw("Logs in last 30 days: \(medication.logsInLast30Days)", font: .systemFont(ofSize: 12), spacingAfter: 4)
				draw("Average daily usage: \(medication.averageDailyUsage)", font: .systemFont(ofSize: 12), spacingAfter: 4)
				draw("Refill status: \(medication.refillStatus)", font: .systemFont(ofSize: 12), spacingAfter: 16)
			}

			draw("Disclaimer", font: .boldSystemFont(ofSize: 14), spacingAfter: 6)
			draw(summary.disclaimer, font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 0)
		}
	}
}

// GetMedicationInfoIntent.swift
// App Intent for querying detailed information about a specific medication

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation
import SwiftUI
import SFSafeSymbols

@available(iOS 16.0, *)
struct GetMedicationInfoIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Medication Info"
	static let description = IntentDescription("Get detailed information about a specific medication")
	static let openAppWhenRun: Bool = false

	@Parameter(title: "Medication", description: "The medication to query")
	var medication: MedicationEntity?

	@Parameter(title: "Medication Name", description: "The name of the medication")
	var medicationName: String?

	private let logger = DHLogger(category: "GetMedicationInfoIntent")

	@MainActor
	func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
		// Migration waits for both Boutique stores before reading their snapshot.
		try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
		logger.info("Performing GetMedicationInfoIntent")

		// Determine which medication to use
		let targetMedication: ANMedicationConcept

		if let providedMedication = medication {
			guard let current = DataStore.shared.medications.first(where: { $0.id == providedMedication.medication.id }) else {
				return .result(dialog: IntentDialog("That medication is no longer available."), view: EmptyMedicationInfoView())
			}
			targetMedication = current
			logger.info("Using entity medication")
		} else if let name = medicationName, !name.isEmpty {
			logger.info("Searching for medication by provided name")
			guard let foundMedication = MedicationSearchUtility.findBestMatch(for: name) else {
				logger.warning("No medication found for provided name")
				return .result(
					dialog: IntentDialog("I couldn't find a medication named \(name)."),
					view: EmptyMedicationInfoView()
				)
			}
			targetMedication = foundMedication
		} else {
			logger.warning("No medication specified")
			return .result(
				dialog: IntentDialog("Please specify which medication you'd like information about."),
				view: EmptyMedicationInfoView()
			)
		}

		// Gather medication info
		let info = gatherMedicationInfo(for: targetMedication)

		// Build dialog response
		var dialogParts: [String] = []
		dialogParts.append(String(localized: "Here's information about \(targetMedication.displayName):"))

		if let dose = targetMedication.prescribedDoseAmount,
		   let unit = targetMedication.prescribedUnit
		{
			dialogParts.append(String(localized: "\(String(localized: "Prescribed Dose")): \(unit.localizedCompactAmount(for: dose))"))
		}

		if let quantity = targetMedication.quantity,
		   let unit = targetMedication.prescribedUnit
		{
			dialogParts.append(String(localized: "\(String(localized: "Remaining")): \(unit.localizedCompactAmount(for: quantity))"))
		}

		if let nextRefill = targetMedication.nextRefillDate {
			let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
			if daysUntil > 0 {
				dialogParts.append(String(localized: "Next refill in \(daysUntil) days"))
			} else {
				dialogParts.append(String(localized: "Refill is due"))
			}
		}

		if let hours = targetMedication.minimumHoursBetweenDoses {
			dialogParts.append(String(localized: "Saved minimum interval is \(hours.formattedAmount) hours"))
		} else {
			dialogParts.append(String(localized: "No minimum interval saved"))
		}
		if let maximum = targetMedication.maximumDailyDoseAmount {
			let amount = targetMedication.prescribedUnit.map { $0.localizedCompactAmount(for: maximum) }
				?? String(localized: "\(maximum.formattedAmount) \(String(localized: "(unit missing)"))")
			dialogParts.append(String(localized: "Saved rolling 24-hour maximum: \(amount)"))
		} else {
			dialogParts.append(String(localized: "No maximum amount in 24 hours saved"))
		}
		dialogParts.append(info.availabilityText)
		let dialog = dialogParts.joined(separator: ". ") + String(localized: ". Follow your prescription and care instructions.")

		logger.info("Retrieved medication info")

		return .result(
			dialog: IntentDialog(stringLiteral: dialog),
			view: MedicationInfoView(info: info)
		)
	}

	@MainActor
	private func gatherMedicationInfo(for medication: ANMedicationConcept) -> MedicationDetailInfo {
		let events = DataStore.shared.events
			.filter { $0.medication?.id == medication.id && $0.eventType == .doseTaken && $0.date <= Date() }
			.sorted { $0.date > $1.date }

		let lastTaken = events.first?.date

		var daysUntilRefill: Int?
		if let refillDate = medication.nextRefillDate {
			daysUntilRefill = Calendar.current.dateComponents([.day], from: Date(), to: refillDate).day
		}

		// Count doses in last 7 days
		let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
		let recentDoses = events.filter { $0.date >= sevenDaysAgo }.count

		return MedicationDetailInfo(
			name: medication.displayName,
			clinicalName: medication.clinicalName,
			prescribedDose: medication.prescribedDoseAmount,
			prescribedUnit: medication.prescribedUnit,
			quantity: medication.quantity,
			minimumInterval: medication.minimumHoursBetweenDoses.map { $0 * 3600 },
			maximumDailyAmount: medication.maximumDailyDoseAmount,
			availabilityText: availabilityText(for: medication),
			lastTaken: lastTaken,
			daysUntilRefill: daysUntilRefill,
			recentDosesCount: recentDoses
		)
	}
	@MainActor
	private func availabilityText(for medication: ANMedicationConcept) -> String {
		let now = Date()
		let availability = MedicationDoseGuidanceService().availability(for: medication, at: now, events: DataStore.shared.events, profile: MedicationSafetyProfileStore.shared.profile(for: medication.id))
		if let nextDate = availability.eligibleDate, nextDate > now {
			return String(localized: "Next saved window: \(nextDate.formatted(date: .abbreviated, time: .shortened))")
		}
		return availability.eligibleDate != nil ? String(localized: "Saved limits met based on logged doses") : availability.message
	}

}

// MARK: - Supporting Types

struct MedicationDetailInfo {
	let name: String
	let clinicalName: String
	let prescribedDose: Double?
	let prescribedUnit: ANUnitConcept?
	let quantity: Double?
	let minimumInterval: TimeInterval?
	let maximumDailyAmount: Double?
	let availabilityText: String
	let lastTaken: Date?
	let daysUntilRefill: Int?
	let recentDosesCount: Int
}

// MARK: - Snippet Views

struct MedicationInfoView: View {
	@Environment(\.fontFamily) private var fontFamily
	let info: MedicationDetailInfo

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header
			HStack {
				Image(systemSymbol: .pillsFill)
					.font(.customFont(fontFamily, style: .title2))
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 2) {
					Text(info.name)
						.font(.customFont(fontFamily, style: .headline))
						.noTruncate()

					if info.name != info.clinicalName {
						Text(info.clinicalName)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}
				}
			}

			Divider()

			// Details
			VStack(alignment: .leading, spacing: 12) {
				// Prescribed dose
				if let dose = info.prescribedDose,
				   let unit = info.prescribedUnit
				{
					InfoRow(
						icon: .pills,
						label: String(localized: "Prescribed Dose"),
						value: unit.localizedCompactAmount(for: dose)
					)
				}

				InfoRow(icon: .clock, label: String(localized: "Minimum interval"), value: info.minimumInterval.map { String(localized: "\(($0 / 3600).formattedAmount) hours") } ?? String(localized: "Not saved"))
				InfoRow(icon: .chartBar, label: String(localized: "Rolling 24h maximum"), value: info.maximumDailyAmount.map { maximum in info.prescribedUnit.map { $0.localizedCompactAmount(for: maximum) } ?? String(localized: "\(maximum.formattedAmount) \(String(localized: "(unit missing)"))") } ?? String(localized: "Not saved"))
				Text(info.availabilityText)
					.font(.customFont(fontFamily, style: .caption))

				// Quantity remaining
				if let quantity = info.quantity,
				   let unit = info.prescribedUnit
				{
					InfoRow(
						icon: .squareStack3dUp,
						label: String(localized: "Remaining"),
						value: unit.localizedCompactAmount(for: quantity),
						valueColor: quantityColor(for: quantity)
					)
				}

				// Last taken
				if let lastTaken = info.lastTaken {
					InfoRow(
						icon: .clock,
						label: String(localized: "Last Taken"),
						value: lastTaken.formatted(date: .abbreviated, time: .shortened)
					)
				}

				// Refill status
				if let daysUntil = info.daysUntilRefill {
					InfoRow(
						icon: .calendar,
						label: String(localized: "Refill"),
						value: daysUntil > 0 ? String(localized: "in \(daysUntil) days") : String(localized: "due now"),
						valueColor: daysUntil <= 7 ? .orange : .primary
					)
				}

				// Recent activity
				InfoRow(
					icon: .chartBar,
					label: String(localized: "Last 7 Days"),
					value: String(localized: "Doses: \(info.recentDosesCount)")
				)
			}
		}
		.padding()
	}

	private func quantityColor(for quantity: Double) -> Color {
		if quantity < 10 {
			return .red
		} else if quantity < 30 {
			return .orange
		} else {
			return .green
		}
	}
}

struct InfoRow: View {
	@Environment(\.fontFamily) private var fontFamily
	let icon: SFSymbol
	let label: String
	let value: String
	var valueColor: Color = .primary

	var body: some View {
		HStack {
			Image(systemSymbol: icon)
				.font(.customFont(fontFamily, style: .caption))
				.foregroundStyle(.secondary)
				.frame(width: 20)

			Text(label)
				.font(.customFont(fontFamily, style: .caption))
				.foregroundStyle(.secondary)

			Spacer()

			Text(value)
				.font(.customFont(fontFamily, style: .caption, weight: .medium))
				.foregroundStyle(valueColor)
		}
	}
}

struct EmptyMedicationInfoView: View {
	@Environment(\.fontFamily) private var fontFamily
	var body: some View {
		VStack(spacing: 12) {
			Image(systemSymbol: .pills)
				.font(.customFont(fontFamily, style: .largeTitle))
				.foregroundStyle(.secondary)

			Text("Medication Not Found")
				.font(.customFont(fontFamily, style: .headline))
				.foregroundStyle(.secondary)
		}
		.padding()
	}
}

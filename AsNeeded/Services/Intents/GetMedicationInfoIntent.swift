// GetMedicationInfoIntent.swift
// App Intent for querying detailed information about a specific medication

import Foundation
import SwiftUI
import AppIntents
import ANModelKit
import DHLoggingKit

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
		logger.info("Performing GetMedicationInfoIntent")

		// Determine which medication to use
		let targetMedication: ANMedicationConcept

		if let providedMedication = medication {
			targetMedication = providedMedication.medication
			logger.info("Using entity medication: \(targetMedication.id.uuidString)")
		} else if let name = medicationName, !name.isEmpty {
			logger.info("Searching for medication by name: \(name)")
			guard let foundMedication = MedicationSearchUtility.findBestMatch(for: name) else {
				logger.warning("No medication found matching: \(name)")
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
		dialogParts.append("Here's information about \(targetMedication.displayName):")

		if let dose = targetMedication.prescribedDoseAmount,
		   let unit = targetMedication.prescribedUnit {
			dialogParts.append("Prescribed dose is \(dose.formattedAmount) \(unit.displayName)")
		}

		if let quantity = targetMedication.quantity,
		   let unit = targetMedication.prescribedUnit {
			dialogParts.append("You have \(quantity.formattedAmount) \(unit.displayName) remaining")
		}

		if let nextRefill = targetMedication.nextRefillDate {
			let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
			if daysUntil > 0 {
				dialogParts.append("Next refill in \(daysUntil) days")
			} else {
				dialogParts.append("Refill is due")
			}
		}

		let dialog = dialogParts.joined(separator: ". ") + "."

		logger.info("Retrieved info for medication: \(targetMedication.displayName)")

		return .result(
			dialog: IntentDialog(stringLiteral: dialog),
			view: MedicationInfoView(info: info)
		)
	}

	@MainActor
	private func gatherMedicationInfo(for medication: ANMedicationConcept) -> MedicationDetailInfo {
		let events = DataStore.shared.events
			.filter { $0.medication?.id == medication.id }
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
			minimumInterval: nil, // minimumIntervalSeconds doesn't exist yet
			lastTaken: lastTaken,
			daysUntilRefill: daysUntilRefill,
			recentDosesCount: recentDoses
		)
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
	let lastTaken: Date?
	let daysUntilRefill: Int?
	let recentDosesCount: Int
}

// MARK: - Snippet Views

struct MedicationInfoView: View {
	let info: MedicationDetailInfo

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header
			HStack {
				Image(systemName: "pills.fill")
					.font(.title2)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 2) {
					Text(info.name)
						.font(.headline)

					if info.name != info.clinicalName {
						Text(info.clinicalName)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}

			Divider()

			// Details
			VStack(alignment: .leading, spacing: 12) {
				// Prescribed dose
				if let dose = info.prescribedDose,
				   let unit = info.prescribedUnit {
					InfoRow(
						icon: "pills",
						label: "Prescribed Dose",
						value: "\(dose.formattedAmount) \(unit.displayName)"
					)
				}

				// Quantity remaining
				if let quantity = info.quantity,
				   let unit = info.prescribedUnit {
					InfoRow(
						icon: "square.stack.3d.up",
						label: "Remaining",
						value: "\(quantity.formattedAmount) \(unit.displayName)",
						valueColor: quantityColor(for: quantity)
					)
				}

				// Last taken
				if let lastTaken = info.lastTaken {
					InfoRow(
						icon: "clock",
						label: "Last Taken",
						value: lastTaken.formatted(date: .abbreviated, time: .shortened)
					)
				}

				// Refill status
				if let daysUntil = info.daysUntilRefill {
					InfoRow(
						icon: "calendar",
						label: "Refill",
						value: daysUntil > 0 ? "in \(daysUntil) days" : "due now",
						valueColor: daysUntil <= 7 ? .orange : .primary
					)
				}

				// Recent activity
				InfoRow(
					icon: "chart.bar",
					label: "Last 7 Days",
					value: "\(info.recentDosesCount) dose\(info.recentDosesCount == 1 ? "" : "s")"
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
	let icon: String
	let label: String
	let value: String
	var valueColor: Color = .primary

	var body: some View {
		HStack {
			Image(systemName: icon)
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: 20)

			Text(label)
				.font(.caption)
				.foregroundStyle(.secondary)

			Spacer()

			Text(value)
				.font(.caption.weight(.medium))
				.foregroundStyle(valueColor)
		}
	}
}

struct EmptyMedicationInfoView: View {
	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: "pills")
				.font(.largeTitle)
				.foregroundStyle(.secondary)

			Text("Medication Not Found")
				.font(.headline)
				.foregroundStyle(.secondary)
		}
		.padding()
	}
}

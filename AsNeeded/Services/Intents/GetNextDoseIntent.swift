// GetNextDoseIntent.swift
// App Intent for checking saved dose limits.

import ANModelKit
import AppIntents
import Foundation
import SFSafeSymbols
import SwiftUI

@available(iOS 16.0, *)
struct GetNextDoseIntent: AppIntent {
	static let title: LocalizedStringResource = "Check Next Dose"
	static let description = IntentDescription("Check the next window based on your saved dose limits and logged doses")
	static let openAppWhenRun: Bool = false

	@Parameter(title: "Medication", description: "The medication to check (optional)")
	var medication: MedicationEntity?

	@MainActor
	func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
		// Migration waits for both Boutique stores before reading their snapshot.
		try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
		let now = Date()
		let events = DataStore.shared.events
		let profiles = MedicationSafetyProfileStore.shared.allProfiles()
		let target: ANMedicationConcept?
		if let provided = medication {
			target = DataStore.shared.medications.first { $0.id == provided.medication.id && !$0.isArchived }
		} else {
			target = Self.selectMedication(from: DataStore.shared.medications, at: now, events: events, profiles: profiles)
		}
		guard let target else {
			return .result(
				dialog: IntentDialog(stringLiteral: medication == nil ? String(localized: "No active medications are available. Open AsNeeded to add one.") : String(localized: "That medication is no longer active. Choose a different medication in AsNeeded.")),
				view: EmptyMedicationsView()
			)
		}
		let availability = MedicationDoseGuidanceService().availability(
			for: target, at: now, events: events, profile: profiles[target.id.uuidString] ?? .empty
		)
		let nextDate = availability.eligibleDate
		let status: String
		if let nextDate, nextDate > now {
			status = String(localized: "Next saved window: \(nextDate.formatted(date: .abbreviated, time: .shortened)).")
		} else {
			status = nextDate != nil ? String(localized: "Saved limits met based on logged doses.") : availability.message
		}
		return .result(
			dialog: IntentDialog("\(target.displayName): \(status) Follow your prescription and care instructions."),
			view: NextDoseView(medicationName: target.displayName, statusText: status)
		)
	}

	static func selectMedication(
		from medications: [ANMedicationConcept],
		at date: Date,
		events: [ANEventConcept],
		profiles: [String: MedicationSafetyProfile]
	) -> ANMedicationConcept? {
		let service = MedicationDoseGuidanceService()
		return medications.filter { !$0.isArchived }.min { left, right in
			let leftDate = service.availability(for: left, at: date, events: events, profile: profiles[left.id.uuidString] ?? .empty).eligibleDate ?? .distantFuture
			let rightDate = service.availability(for: right, at: date, events: events, profile: profiles[right.id.uuidString] ?? .empty).eligibleDate ?? .distantFuture
			if leftDate == rightDate {
				return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
			}
			return leftDate < rightDate
		}
	}
}

// MARK: - Snippet Views
struct NextDoseView: View {
	@Environment(\.fontFamily) private var fontFamily
	let medicationName: String
	let statusText: String

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label {
				Text(medicationName)
					.font(.customFont(fontFamily, style: .headline))
					.noTruncate()
			} icon: {
				Image(systemSymbol: .pillsFill).foregroundStyle(.accent)
			}
			Text(statusText)
				.font(.customFont(fontFamily, style: .subheadline))
			Text("Based on saved limits and logged doses. Follow your prescription and care instructions.")
				.font(.customFont(fontFamily, style: .caption))
				.foregroundStyle(.secondary)
		}
		.padding()
	}
}

struct EmptyMedicationsView: View {
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		VStack(spacing: 12) {
			Image(systemSymbol: .pills).foregroundStyle(.secondary)
			Text("No Active Medications")
				.font(.customFont(fontFamily, style: .headline))
				.foregroundStyle(.secondary)
		}
		.padding()
	}
}

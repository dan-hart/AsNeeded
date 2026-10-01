// LogDosePickerModel.swift
// Ordering, filtering and labels for the medication-agnostic Log Dose picker.

import ANModelKit
import Foundation

/// One medication in the Log Dose picker with the date of its most recent dose.
struct LogDosePickerItem: Identifiable, Equatable {
	let medication: ANMedicationConcept
	let lastDoseDate: Date?

	var id: UUID { medication.id }
}

/// Pure rules behind the Log Dose picker so the sheet stays a thin view.
enum LogDosePickerModel {
	/// With this many medications or more, the picker focuses its search field on open.
	static let searchAutoFocusThreshold = 8

	/// Builds picker items from the medications a user can log, most recently logged first.
	/// Medications that have never been logged follow, alphabetically, so a new medication is still easy to
	/// find without pushing the ones the user actually reaches for down the list.
	static func items(medications: [ANMedicationConcept], events: [ANEventConcept]) -> [LogDosePickerItem] {
		var lastDoseByMedication: [UUID: Date] = [:]
		for event in events where event.eventType == .doseTaken {
			guard let medicationID = event.medication?.id else { continue }
			if let existing = lastDoseByMedication[medicationID], existing >= event.date {
				continue
			}
			lastDoseByMedication[medicationID] = event.date
		}

		return medications
			.map { LogDosePickerItem(medication: $0, lastDoseDate: lastDoseByMedication[$0.id]) }
			.sorted { lhs, rhs in
				switch (lhs.lastDoseDate, rhs.lastDoseDate) {
				case let (left?, right?):
					if left != right {
						return left > right
					}
				case (.some, .none):
					return true
				case (.none, .some):
					return false
				case (.none, .none):
					break
				}
				return lhs.medication.displayName.localizedCaseInsensitiveCompare(rhs.medication.displayName) == .orderedAscending
			}
	}

	/// Items whose display, clinical or nickname contains the query. An empty query returns everything.
	static func filter(_ items: [LogDosePickerItem], query: String) -> [LogDosePickerItem] {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return items }

		return items.filter { item in
			let medication = item.medication
			let candidates = [medication.displayName, medication.clinicalName, medication.nickname ?? ""]
			return candidates.contains { $0.localizedCaseInsensitiveContains(trimmed) }
		}
	}

	/// Short "last taken" label for a tile: "Today 10:13", "Yesterday 21:40", "Sep 12", or "Not logged yet".
	static func lastTakenText(for date: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
		guard let date else {
			return String(localized: "Not logged yet")
		}

		let time = date.formatted(date: .omitted, time: .shortened)
		if calendar.isDate(date, inSameDayAs: now) {
			return String(localized: "Today \(time)")
		}
		if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
		   calendar.isDate(date, inSameDayAs: yesterday)
		{
			return String(localized: "Yesterday \(time)")
		}
		return date.formatted(date: .abbreviated, time: .omitted)
	}
}

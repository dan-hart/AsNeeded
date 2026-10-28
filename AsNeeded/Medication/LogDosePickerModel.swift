import ANModelKit
import Foundation

/// Selection/search rules adapted from the earlier picker in commit 8fab48f.
/// Preserve the person's list order and exclude archived medications.
enum LogDosePickerModel {
	static func medication(forDeepLink id: String, from medications: [ANMedicationConcept]) -> ANMedicationConcept? {
		guard let medicationID = UUID(uuidString: id) else { return nil }
		return medications.first { $0.id == medicationID && !$0.isArchived }
	}

	static func medications(from medications: [ANMedicationConcept], matching query: String = "") -> [ANMedicationConcept] {
		let active = medications.filter { !$0.isArchived }
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return active }

		return active.filter { medication in
			[medication.displayName, medication.clinicalName, medication.nickname ?? ""]
				.contains { $0.localizedCaseInsensitiveContains(trimmed) }
		}
	}
}

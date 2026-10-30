import ANModelKit
import Foundation

/// Selection/search rules adapted from the earlier picker in commit 8fab48f.
/// Preserve the person's list order and exclude archived medications.
enum LogDosePickerModel {
	/// An unavailable explicit filter must never silently switch to the last logged medication.
	static func quickLogMedication(selectedID: UUID?, useLastLogged: Bool,
		lastLoggedID: UUID?, from medications: [ANMedicationConcept]) -> ANMedicationConcept? {
		guard let id = useLastLogged ? lastLoggedID : selectedID else { return nil }
		return medications.first { $0.id == id && !$0.isArchived }
	}

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

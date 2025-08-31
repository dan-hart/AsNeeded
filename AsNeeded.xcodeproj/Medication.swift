// Medication.swift
// Defines a persistable Medication model using ANModelKit and sets up a Boutique store.

import Foundation
import ANModelKit
import Boutique

// MARK: - Medication Model
@Model
struct Medication: Identifiable, Codable, Equatable, Hashable {
	@ID var id: UUID = UUID()
	var name: String
	var dosage: String?
	var asNeeded: Bool
	var info: String
	var rxCUI: String? // RxNorm Concept Unique Identifier
	var history: [Date] = [] // Log of taken doses
	
	var mostRecentTaken: Date? {
		history.sorted(by: >).first
	}
}

// MARK: - Boutique Store
extension Medication {
	static let store = Store<Medication>(
		storage: SQLiteStorageEngine.default(appending: "medications.sqlite"),
		cacheIdentifier: \Medication.id
	)
}

#if DEBUG
import SwiftUI

#Preview("Medication Row Preview") {
	MedicationRow(medication: Medication(
		name: "Ibuprofen",
		dosage: "200mg",
		asNeeded: true,
		info: "Pain relief",
		rxCUI: "5640",
		history: [Date().addingTimeInterval(-3600*24)]
	))
}

#Preview("Medication Edit Preview") {
	MedicationEditView(
		medication: Medication(
			name: "Ibuprofen",
			dosage: "200mg",
			asNeeded: true,
			info: "Pain relief",
			rxCUI: "5640",
			history: []),
		onSave: { _ in },
		onCancel: {}
	)
}
#endif

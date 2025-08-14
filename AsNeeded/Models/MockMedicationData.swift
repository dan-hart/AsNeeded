// Create a new file for mock medication data and model for the POC.
// This struct and mock list will be used to populate the medication list in MedicationView until HealthKit integration is ready.

import Foundation

struct MockMedication: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let dosage: String?
    let asNeeded: Bool
    let info: String
    let history: [Date]
    
    // For display purposes
    var mostRecentTaken: Date? {
        history.sorted(by: >).first
    }
}

extension MockMedication {
    static let asNeededMedications: [MockMedication] = [
        MockMedication(
            name: "Albuterol Inhaler",
            dosage: "2 puffs as needed",
            asNeeded: true,
            info: "Used for relief of asthma symptoms. Fast-acting bronchodilator.",
            history: [Date().addingTimeInterval(-3600 * 24 * 1), Date().addingTimeInterval(-3600 * 24 * 3)]
        ),
        MockMedication(
            name: "Ibuprofen",
            dosage: "400mg as needed",
            asNeeded: true,
            info: "Pain reliever and anti-inflammatory medication.",
            history: [Date().addingTimeInterval(-3600 * 24 * 2), Date().addingTimeInterval(-3600 * 24 * 7)]
        ),
        MockMedication(
            name: "Loratadine",
            dosage: "10mg as needed",
            asNeeded: true,
            info: "Antihistamine used for allergy relief.",
            history: []
        )
    ]
}

// Compile alongside WristAsNeeded Watch App/WatchMedication.swift in a macOS Swift Testing harness.
import Foundation
import Testing

@Suite("Watch availability states")
struct WatchMedicationAvailabilityTests {
	@Test("Medication without timing guidance starts unknown")
	func defaultsToUnknown() {
		let medication = WatchMedication(id: UUID(), displayName: "Test", quantity: 10)
		#expect(!medication.canTake(at: Date(timeIntervalSince1970: 1_800_000_000)))
	}

	@Test("Legacy watch payload without availability never implies clearance")
	func missingPayloadIsUnknown() {
		let medication = WatchMedication(from: ["id": UUID().uuidString, "displayName": "Test", "quantity": 10.0])
		#expect(!medication.canTakeNow)
		#expect(medication.nextDoseDate == nil)
	}

	@Test("Known future availability updates at the exact saved window")
	func futureWindowBoundary() {
		let now = Date(timeIntervalSince1970: 1_800_000_000)
		let nextDate = now.addingTimeInterval(3600)
		let medication = WatchMedication(id: UUID(), displayName: "Test", quantity: 10, canTakeNow: false, nextDoseDate: nextDate)
		#expect(!medication.canTake(at: now))
		#expect(medication.canTake(at: nextDate))
	}
}

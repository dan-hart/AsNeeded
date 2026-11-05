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

@Suite("Watch dictionary and Codable compatibility")
struct WatchMedicationCompatibilityTests {
	@Test("Legacy literal payload parses and Codable roundtrip preserves values")
	func legacyRoundtrip() throws {
		let id = UUID()
		let payload: [String: Any] = [
			"id": id.uuidString, "displayName": "Synthetic medication", "quantity": 2.5,
			"prescribedDoseAmount": 0.5, "prescribedUnit": "tablet", "canTakeNow": false,
			"lowStock": true, "refillSoon": true, "statusMessage": "Legacy guidance",
		]
		let decoded = WatchMedication(from: payload)
		#expect(decoded.id == id)
		#expect(decoded.displayName == "Synthetic medication")
		#expect(decoded.quantity == 2.5)
		#expect(decoded.prescribedDoseAmount == 0.5)
		#expect(decoded.prescribedUnit == "tablet")
		#expect(decoded.lowStock && decoded.refillSoon)
		#expect(!decoded.canTakeNow)
		#expect(decoded.statusMessage == "Legacy guidance")
		let encoded = try JSONEncoder().encode(decoded)
		let dictionary = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		#expect(dictionary["canTakeNow"] as? Bool == false)
		#expect(dictionary["payloadCanTakeNow"] == nil)
		let reopened = try JSONDecoder().decode(WatchMedication.self, from: encoded)
		#expect(reopened.id == id)
		#expect(reopened.quantity == decoded.quantity)
		#expect(reopened.statusMessage == decoded.statusMessage)
	}

	@Test("Missing or malformed metadata preserves legacy unknown defaults")
	func malformedMetadata() {
		for id: Any in [NSNull(), "invalid", 123] {
			let decoded = WatchMedication(from: ["id": id, "canTakeNow": "true", "nextDoseDate": "invalid", "statusMessageKey": 123, "statusMessage": "Legacy unknown"])
			#expect(!decoded.canTakeNow)
			#expect(decoded.nextDoseDate == nil)
			#expect(decoded.quantity == 0)
			#expect(decoded.statusMessage == "Legacy unknown")
		}
	}
}

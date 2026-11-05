@testable import AsNeeded
import ANModelKit
import Foundation
import Testing

struct WatchMessageValidationTests {
	@Test("Watch stock updates preserve fractional values and allow zero")
	func validQuantities() {
		for amount in [0.0, 0.25, 1.5, 100] {
			let update = QuantityUpdateData(from: ["medicationId": UUID().uuidString, "quantity": amount])
			#expect(update.isValid)
			#expect(update.quantity == amount)
		}
	}

	@Test("Missing or invalid stock updates cannot be acknowledged as saved")
	func invalidQuantities() {
		let id = UUID().uuidString
		#expect(!QuantityUpdateData(from: ["medicationId": id]).isValid)
		#expect(!QuantityUpdateData(from: ["medicationId": "invalid", "quantity": 1.0]).isValid)
		for amount in [-0.25, Double.nan, Double.infinity, -Double.infinity] {
			#expect(!QuantityUpdateData(from: ["medicationId": id, "quantity": amount]).isValid)
		}
	}

	@Test("Watch dose payload requires a positive finite amount and known unit")
	func doseValidation() {
		let valid: [String: Any] = [
			"medicationId": UUID().uuidString,
			"doseAmount": 0.25,
			"doseUnit": ANUnitConcept.tablet.rawValue,
			"quantityConsumed": 0.25,
		]
		#expect(LogDoseData(from: valid).isValid)
		for amount in [0.0, -1.0, Double.nan, Double.infinity] {
			var payload = valid
			payload["doseAmount"] = amount
			#expect(!LogDoseData(from: payload).isValid)
		}
		var payload = valid
		payload["doseUnit"] = "not-a-unit"
		#expect(!LogDoseData(from: payload).isValid)
		payload = valid
		payload["quantityConsumed"] = -1.0
		#expect(!LogDoseData(from: payload).isValid)
	}
	@Test("Malformed Watch retry identifiers and timestamps are rejected")
	func invalidRetryMetadata() {
		let valid: [String: Any] = ["medicationId": UUID().uuidString, "doseAmount": 0.5, "doseUnit": ANUnitConcept.tablet.rawValue]
		let invalidValues: [Any] = ["invalid", 123]
		for invalid in invalidValues {
			var payload = valid
			payload["eventID"] = invalid
			#expect(!LogDoseData(from: payload).isValid)
		}
		var payload = valid
		payload["date"] = "invalid"
		#expect(!LogDoseData(from: payload).isValid)
	}

	@Test("Watch retry identity and dose time survive decoding; older payloads remain readable")
	func retryIdentityIsPreserved() {
		let id = UUID()
		let date = Date(timeIntervalSince1970: 1_700_000_000)
		let payload: [String: Any] = ["medicationId": UUID().uuidString, "doseAmount": 0.5, "doseUnit": ANUnitConcept.tablet.rawValue, "eventID": id.uuidString, "date": date]
		let decoded = LogDoseData(from: payload)
		#expect(decoded.isValid)
		#expect(decoded.eventID == id)
		#expect(decoded.date == date)
		var old = payload
		old.removeValue(forKey: "eventID")
		old.removeValue(forKey: "date")
		#expect(LogDoseData(from: old).isValid)
	}

	@Test("Literal legacy envelopes and shared keys select the same phone DTOs")
	func envelopeCompatibility() {
		#expect(SendableMessage(from: ["getMedications": "request"]).getMedications)
		let id = UUID().uuidString
		let dose: [String: Any] = [SharedPlatformContracts.WatchMessage.medicationId: id, SharedPlatformContracts.WatchMessage.doseAmount: 0.5, SharedPlatformContracts.WatchMessage.doseUnit: ANUnitConcept.tablet.rawValue]
		let decoded = SendableMessage(from: [SharedPlatformContracts.WatchMessage.logDose: dose])
		#expect(decoded.logDoseData?.isValid == true)
		#expect(decoded.logDoseData?.eventID == nil)
		#expect(decoded.logDoseData?.date == nil)
		#expect(SendableMessage(from: ["updateQuantity": ["medicationId": id, "quantity": 0.25]]).quantityUpdateData?.quantity == 0.25)
		#expect(SendableMessage(from: ["logDose": "invalid"]).logDoseData == nil)
		#expect(SendableMessage(from: ["updateQuantity": NSNull()]).quantityUpdateData == nil)
	}

}

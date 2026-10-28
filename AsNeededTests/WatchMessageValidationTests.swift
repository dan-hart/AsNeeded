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
}

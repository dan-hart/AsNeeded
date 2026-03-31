import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("DoseReflectionCodec Tests", .tags(.unit))
struct DoseReflectionCodecTests {
	@Test("Plain text notes decode as a freeform reflection")
	func decodePlainTextNote() {
		let reflection = DoseReflectionCodec.reflection(from: "Took with dinner")

		#expect(reflection?.note == "Took with dinner")
		#expect(reflection?.reason == nil)
	}

	@Test("Structured reflections round trip")
	func structuredReflectionsRoundTrip() throws {
		let original = DoseReflection(
			reason: "Breakthrough pain",
			symptomSeverityBefore: 7,
			symptomSeverityAfter: 3,
			effectiveness: 4,
			sideEffects: ["Drowsy", "Dry mouth"],
			note: "Helpful within thirty minutes"
		)

		let encoded = try DoseReflectionCodec.encode(original)
		let decoded = try #require(DoseReflectionCodec.reflection(from: encoded))

		#expect(decoded == original)
		#expect(DoseReflectionCodec.displayNote(from: encoded) == "Helpful within thirty minutes")
	}

	@Test("Malformed structured notes fall back to the raw note text")
	func malformedStructuredNotesFallback() {
		let raw = "\(DoseReflectionCodec.marker){not-json"
		let reflection = DoseReflectionCodec.reflection(from: raw)

		#expect(reflection?.note == raw)
		#expect(reflection?.reason == nil)
	}

	@Test("Updating note text preserves structured fields")
	func updatingNotePreservesStructuredFields() throws {
		let original = DoseReflection(
			reason: "Headache",
			symptomSeverityBefore: 6,
			symptomSeverityAfter: 2,
			effectiveness: 5,
			sideEffects: ["Sleepy"],
			note: "Initial note"
		)
		let encoded = try DoseReflectionCodec.encode(original)

		let updated = try DoseReflectionCodec.updatingNote(
			in: encoded,
			with: "Updated note"
		)

		let decoded = try #require(DoseReflectionCodec.reflection(from: updated))
		#expect(decoded.reason == "Headache")
		#expect(decoded.effectiveness == 5)
		#expect(decoded.note == "Updated note")
	}
}

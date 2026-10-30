import ANModelKit
@testable import AsNeeded
import Testing

@MainActor
@Suite("Session-only Demo Mode")
struct DemoModeStateTests {
	@Test("Names remain unchanged until enabled, and a new session always starts off")
	func sessionLifetime() {
		let state = DemoModeState(medicationNames: { ["Synthetic clinical"] })
		#expect(!state.isEnabled)
		#expect(state.name("Synthetic clinical") == "Synthetic clinical")
		state.enable()
		#expect(state.name("Synthetic clinical") == "Hidden medication")
		#expect(state.name("").isEmpty)
		#expect(!DemoModeState(medicationNames: { [] }).isEnabled)
	}

	@Test("Declining exit keeps names hidden; only confirmation reveals them")
	func explicitExit() {
		let state = DemoModeState(medicationNames: { [] })
		state.enable()
		state.confirmDisable(false)
		#expect(state.isEnabled)
		state.confirmDisable(true)
		#expect(!state.isEnabled)
		#expect(state.name("Synthetic") == "Synthetic")
	}

	@Test("Free text redacts both names case-insensitively without modifying the medication")
	func textPrivacy() {
		let medication = ANMedicationConcept(clinicalName: "Synthetic clinical", nickname: "Example relief")
		let state = DemoModeState(medicationNames: { [medication.clinicalName, medication.nickname ?? ""] })
		let text = "Logged SYNTHETIC CLINICAL (example relief) at 18:00."
		#expect(state.text(text) == text)
		state.enable()
		#expect(state.text(text) == "Logged Hidden medication (Hidden medication) at 18:00.")
		#expect(medication.clinicalName == "Synthetic clinical")
		#expect(medication.nickname == "Example relief")
	}

	@Test("Overlapping names redact original text once, including names in the placeholder")
	func overlappingNames() {
		let state = DemoModeState(medicationNames: { ["med", "medication", "", "Synthetic"] })
		state.enable()
		#expect(state.text("Synthetic medication and med") == "Hidden medication Hidden medication and Hidden medication")
	}
	@Test("Canonical Unicode names and regex punctuation cannot reveal names")
	func unicodeAndLiteralNames() {
		let state = DemoModeState(medicationNames: { ["Café", "Example (A)+"] })
		state.enable()
		#expect(state.text("Cafe\u{0301} / Example (A)+") == "Hidden medication / Hidden medication")
	}

}

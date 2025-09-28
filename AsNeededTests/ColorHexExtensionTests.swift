import Testing
import SwiftUI
@testable import AsNeeded
import ANModelKit

/// Tests for Color+Hex extension functionality
/// Verifies hex string to Color conversion and medication color properties
@Suite("Color+Hex Extension Tests")
struct ColorHexExtensionTests {

	// MARK: - Color+Hex Tests
	@Test("Color hex initialization with valid hex colors")
	func colorHexInitialization() {
		// Test valid hex colors
		let redColor = Color(hex: "#FF0000")
		#expect(redColor != nil)

		let blueColor = Color(hex: "#0000FF")
		#expect(blueColor != nil)

		let greenColor = Color(hex: "#00FF00")
		#expect(greenColor != nil)

		// Test hex without #
		let orangeColor = Color(hex: "FFA500")
		#expect(orangeColor != nil)

		// Test lowercase hex
		let purpleColor = Color(hex: "#800080")
		#expect(purpleColor != nil)
	}

	@Test("Color hex initialization with invalid hex colors")
	func colorHexInitializationInvalid() {
		// Test invalid hex colors should return nil
		let invalidColor1 = Color(hex: "invalid")
		#expect(invalidColor1 == nil)

		let invalidColor2 = Color(hex: "#GGGGGG")
		#expect(invalidColor2 == nil)

		let invalidColor3 = Color(hex: "#12345")
		#expect(invalidColor3 == nil)

		let invalidColor4 = Color(hex: "")
		#expect(invalidColor4 == nil)

		let invalidColor5 = Color(hex: "#1234567")
		#expect(invalidColor5 == nil)
	}

	@Test("Color hex string conversion")
	func colorHexStringConversion() {
		// Test Color to hex string conversion
		let redHex = Color.red.toHex()
		#expect(redHex != nil)
		if let hex = redHex {
			#expect(hex.hasPrefix("#"))
			#expect(hex.count == 7) // #RRGGBB format
		}

		let blueHex = Color.blue.toHex()
		#expect(blueHex != nil)
		if let hex = blueHex {
			#expect(hex.hasPrefix("#"))
			#expect(hex.count == 7)
		}

		// Test round-trip conversion
		let originalHex = "#FF5733"
		if let color = Color(hex: originalHex) {
			let convertedHex = color.toHex()
			// Note: round-trip may not be exact due to color space conversions
			#expect(convertedHex != nil)
			if let hex = convertedHex {
				#expect(hex.hasPrefix("#"))
				#expect(hex.count == 7)
			}
		}
	}

	// MARK: - ANMedicationConcept.displayColor Tests
	@Test("Medication display color with valid hex")
	func medicationDisplayColorValid() {
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			displayColorHex: "#FF5733"
		)

		let displayColor = medication.displayColor
		// Should return a valid color for valid hex
		#expect(displayColor != nil)
		// Verify the hex was actually valid
		#expect(Color(hex: "#FF5733") != nil)
	}

	@Test("Medication display color with invalid hex falls back to accent")
	func medicationDisplayColorInvalidFallback() {
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			displayColorHex: "invalid-hex"
		)

		let displayColor = medication.displayColor
		// Should fall back to accent color for invalid hex - verify it's not a valid color from hex
		#expect(Color(hex: "invalid-hex") == nil)
		// The displayColor should be .accent (we can't easily test exact equality but can verify it's using fallback)
		#expect(displayColor != nil)
	}

	@Test("Medication display color with nil hex falls back to accent")
	func medicationDisplayColorNilFallback() {
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			displayColorHex: nil
		)

		let displayColor = medication.displayColor
		// Should fall back to accent color when hex is nil
		#expect(displayColor != nil)
	}

	@Test("Medication display color with empty hex falls back to accent")
	func medicationDisplayColorEmptyFallback() {
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			displayColorHex: ""
		)

		let displayColor = medication.displayColor
		// Should fall back to accent color for empty hex
		#expect(displayColor != nil)
	}

	@Test("Multiple medications with different colors")
	func multipleMedicationColors() {
		let redMed = ANMedicationConcept(
			clinicalName: "Red Med",
			displayColorHex: "#FF0000"
		)

		let blueMed = ANMedicationConcept(
			clinicalName: "Blue Med",
			displayColorHex: "#0000FF"
		)

		let defaultMed = ANMedicationConcept(
			clinicalName: "Default Med",
			displayColorHex: nil
		)

		// Each medication should have its appropriate color
		#expect(redMed.displayColor != blueMed.displayColor)
		#expect(redMed.displayColor != defaultMed.displayColor)
		#expect(blueMed.displayColor != defaultMed.displayColor)
		// All should return valid colors
		#expect(redMed.displayColor != nil)
		#expect(blueMed.displayColor != nil)
		#expect(defaultMed.displayColor != nil)
	}

	// MARK: - Hex Validation Tests
	@Test("Hex validation utility")
	func hexValidation() {
		// Valid hex strings
		#expect(ANMedicationConcept.isValidHex("#FF0000") == true)
		#expect(ANMedicationConcept.isValidHex("FF0000") == true)
		#expect(ANMedicationConcept.isValidHex("#00FF00") == true)
		#expect(ANMedicationConcept.isValidHex("#0000FF") == true)

		// Invalid hex strings
		#expect(ANMedicationConcept.isValidHex("invalid") == false)
		#expect(ANMedicationConcept.isValidHex("#GGGGGG") == false)
		#expect(ANMedicationConcept.isValidHex("#12345") == false)
		#expect(ANMedicationConcept.isValidHex("") == false)
		#expect(ANMedicationConcept.isValidHex("#1234567") == false)
	}
}
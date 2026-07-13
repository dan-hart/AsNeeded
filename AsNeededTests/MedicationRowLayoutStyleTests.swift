@testable import AsNeeded
import SwiftUI
import Testing

@Suite("Medication Row Layout Style Tests", .tags(Tag.medication, Tag.unit))
struct MedicationRowLayoutStyleTests {
	@Test("Uses standard layout below 135 percent text size")
	func standardLayout() {
		#expect(MedicationRowLayoutStyle(dynamicTypeSize: .large) == .standard)
		#expect(MedicationRowLayoutStyle(dynamicTypeSize: .xxLarge) == .standard)
	}

	@Test("Uses compact layout at 135 percent text size")
	func compactLayout() {
		#expect(MedicationRowLayoutStyle(dynamicTypeSize: .xxxLarge) == .compact)
	}

	@Test("Uses stacked layout at accessibility text sizes")
	func accessibilityLayout() {
		#expect(MedicationRowLayoutStyle(dynamicTypeSize: .accessibility1) == .accessibility)
		#expect(MedicationRowLayoutStyle(dynamicTypeSize: .accessibility5) == .accessibility)
	}

	@Test("Limits only compact clinical subtitles to one line")
	func clinicalNameLineLimit() {
		#expect(MedicationRowLayoutStyle.compact.clinicalNameLineLimit == 1)
		#expect(MedicationRowLayoutStyle.standard.clinicalNameLineLimit == nil)
		#expect(MedicationRowLayoutStyle.accessibility.clinicalNameLineLimit == nil)
	}

	@Test("Compact quantity omits the remaining qualifier")
	func compactQuantityText() {
		#expect(MedicationRowLayoutStyle.compact.quantityText(for: 100, unitAbbreviation: "mg") == "100 mg")
		#expect(MedicationRowLayoutStyle.compact.quantityText(for: 24, unitAbbreviation: nil) == "24")
	}

	@Test("Standard and accessibility quantities retain the remaining qualifier")
	func remainingQuantityText() {
		#expect(MedicationRowLayoutStyle.standard.quantityText(for: 100, unitAbbreviation: "mg") == "100 mg left")
		#expect(MedicationRowLayoutStyle.accessibility.quantityText(for: 24, unitAbbreviation: nil) == "24 left")
	}
}

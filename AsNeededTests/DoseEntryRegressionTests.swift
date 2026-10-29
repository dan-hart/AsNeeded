@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Dose entry regressions")
struct DoseEntryRegressionTests {
	@Test("Quick times retain all six approved offsets")
	func quickTimes() {
		#expect(LogDoseView.quickTimeSelections.map(\.label) == ["Now", "15 min ago", "30 min ago", "1 hour ago", "4 hours ago", "1 day ago"])
		#expect(LogDoseView.quickTimeSelections.map(\.secondsAgo) == [0, 900, 1800, 3600, 14400, 86400])
	}

	@Test("Typed decimal values use the current locale", arguments: ["en_US", "fr_FR", "de_DE"])
	func localizedInput(_ identifier: String) {
		let locale = Locale(identifier: identifier)
		let text = " 1\(locale.decimalSeparator ?? ".")25 \n"
		#expect(DoseAmountInput.parse(text, locale: locale) == 1.25)
		#expect(DoseAmountInput.parse("0", locale: locale) == 0)
	}

	@Test("Empty, incomplete, and nonfinite entry cannot become a valid dose", arguments: ["", ".", "-", "nan", "inf", "1e999", "one", "1.2.3"])
	func invalidInput(_ text: String) {
		#expect(DoseAmountInput.parse(text, locale: Locale(identifier: "en_US")) == 0)
	}
}

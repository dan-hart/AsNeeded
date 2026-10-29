import Foundation

/// The numeric field retains its draft text while only finite values reach the dose model.
enum DoseAmountInput {
	static func parse(_ text: String, locale: Locale = .current) -> Double {
		let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
		guard let value = Double(normalized), value.isFinite else { return 0 }
		return value
	}
}

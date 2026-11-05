import Foundation

/// Decimal keyboard input only: never infer thousands grouping or accept a numeric prefix.
enum DoseAmountInput {
	/// Invalid drafts keep the existing zero-value behavior for dose steppers.
	static func parse(_ text: String, locale: Locale = .current) -> Double {
		value(from: text, locale: locale) ?? 0
	}

	static func value(from text: String, locale: Locale = .current) -> Double? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let decimalSeparator = locale.decimalSeparator ?? "."
		var normalized = ""
		var hasDecimalSeparator = false
		var digitCount = 0
		var hasExponent = false
		for character in trimmed {
			if character == "." || String(character) == decimalSeparator {
				guard !hasDecimalSeparator, !hasExponent else { return nil }
				hasDecimalSeparator = true
				normalized.append(".")
			} else if (character == "e" || character == "E"), digitCount > 0, !hasExponent {
				hasExponent = true
				normalized.append("e")
			} else if (character == "-" || character == "+") && (normalized.isEmpty || normalized.last == "e") {
				normalized.append(character)
			} else {
				guard character.unicodeScalars.allSatisfy({ $0.properties.generalCategory == .decimalNumber }),
					let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
				normalized.append(String(digit))
				digitCount += 1
			}
		}
		guard digitCount > 0, let value = Double(normalized), value.isFinite else { return nil }
		return value
	}

	/// Retains enough significant digits to round-trip the stored Double without grouping.
	static func text(for value: Double, locale: Locale = .current) -> String {
		value.formatted(.number.locale(locale).grouping(.never).precision(.significantDigits(1...17)))
	}
}

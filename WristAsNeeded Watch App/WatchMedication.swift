import Foundation

struct WatchMedication: Identifiable, Codable {
	let id: UUID
	let displayName: String
	let quantity: Double
	let prescribedDoseAmount: Double?
	let prescribedUnit: String?
	private let payloadCanTakeNow: Bool
	let nextDoseDate: Date?
	let lowStock: Bool
	let refillSoon: Bool
	let statusMessage: String?

	var canTakeNow: Bool {
		canTake(at: Date())
	}

	init(
		id: UUID,
		displayName: String,
		quantity: Double,
		prescribedDoseAmount: Double? = nil,
		prescribedUnit: String? = nil,
		canTakeNow: Bool = false,
		nextDoseDate: Date? = nil,
		lowStock: Bool = false,
		refillSoon: Bool = false,
		statusMessage: String? = nil
	) {
		self.id = id
		self.displayName = displayName
		self.quantity = quantity
		self.prescribedDoseAmount = prescribedDoseAmount
		self.prescribedUnit = prescribedUnit
		self.payloadCanTakeNow = canTakeNow
		self.nextDoseDate = nextDoseDate
		self.lowStock = lowStock
		self.refillSoon = refillSoon
		self.statusMessage = statusMessage
	}

	init(from dict: [String: Any]) {
		id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
		displayName = dict["displayName"] as? String ?? String(localized: "Unknown")
		quantity = dict["quantity"] as? Double ?? 0.0
		prescribedDoseAmount = dict["prescribedDoseAmount"] as? Double
		prescribedUnit = dict["prescribedUnit"] as? String
		payloadCanTakeNow = dict["canTakeNow"] as? Bool ?? false
		nextDoseDate = dict["nextDoseDate"] as? Date
		lowStock = dict["lowStock"] as? Bool ?? false
		refillSoon = dict["refillSoon"] as? Bool ?? false
		if let key = dict["statusMessageKey"] as? String, !key.isEmpty {
			statusMessage = String(localized: String.LocalizationValue(key))
		} else if let nextDoseDate {
			// Resolve date-bearing guidance on Watch so its locale can differ from iPhone.
			statusMessage = nextDoseDate <= Date()
				? String(localized: "Saved limits met based on logged doses. Follow your prescription and care instructions.")
				: String(localized: "Next saved window: \(nextDoseDate.formatted(date: .abbreviated, time: .shortened)). Follow your prescription and care instructions.")
		} else {
			// Unknown/no-date legacy messages have no language-neutral metadata. Preserve them verbatim.
			statusMessage = dict["statusMessage"] as? String
		}
	}

	/// Localize known presentation values without changing the WatchConnectivity unit identifier.
	static func localizedUnit(_ rawValue: String) -> String {
		switch rawValue {
		case "milligram": return String(localized: "Milligram")
		case "gram": return String(localized: "Gram")
		case "microgram": return String(localized: "Microgram")
		case "unit": return String(localized: "Unit")
		case "tablet": return String(localized: "Tablet")
		case "capsule": return String(localized: "Capsule")
		case "chewable": return String(localized: "Chewable")
		case "lozenge": return String(localized: "Lozenge")
		case "suppository": return String(localized: "Suppository")
		case "milliliter": return String(localized: "Milliliter")
		case "liter": return String(localized: "Liter")
		case "teaspoon": return String(localized: "Teaspoon")
		case "drop": return String(localized: "Drop")
		case "sachet": return String(localized: "Sachet")
		case "puff": return String(localized: "Puff")
		case "nebule": return String(localized: "Nebule")
		case "injection": return String(localized: "Injection")
		case "tablespoon": return String(localized: "Tablespoon")
		case "pen": return String(localized: "Pen")
		case "inhaler": return String(localized: "Inhaler")
		case "vial": return String(localized: "Vial")
		case "patch": return String(localized: "Patch")
		case "application": return String(localized: "Application")
		case "spray": return String(localized: "Spray")
		case "strip": return String(localized: "Strip")
		case "film": return String(localized: "Film")
		case "dose": return String(localized: "Dose")
		case "ampule": return String(localized: "Ampule")
		case "bowl": return String(localized: "Bowl")
		case "joint": return String(localized: "Joint")
		case "dab": return String(localized: "Dab")
		case "mg": return String(localized: "mg")
		case "mL": return String(localized: "mL")
		case "units": return String(localized: "units")
		default: return rawValue
		}
	}

	/// Presentation only; selectors and sync payloads retain the original unit and amount.
	static func localizedAmount(_ amount: Double, unit rawValue: String, locale: Locale = .current) -> String {
		// Match the existing two-decimal presentation while keeping a numeric plural argument.
		let displayedAmount = amount.truncatingRemainder(dividingBy: 1) == 0 ? amount : (amount * 100).rounded() / 100
		let phrase: String
		switch rawValue {
		case "milligram", "mg": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") milligrams", locale: locale)
		case "gram": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") grams", locale: locale)
		case "microgram": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") micrograms", locale: locale)
		case "unit", "units": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") units", locale: locale)
		case "tablet": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") tablets", locale: locale)
		case "capsule": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") capsules", locale: locale)
		case "chewable": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") chewables", locale: locale)
		case "lozenge": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") lozenges", locale: locale)
		case "suppository": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") suppositories", locale: locale)
		case "milliliter", "mL": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") milliliters", locale: locale)
		case "liter": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") liters", locale: locale)
		case "teaspoon": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") teaspoons", locale: locale)
		case "drop": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") drops", locale: locale)
		case "sachet": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") sachets", locale: locale)
		case "puff": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") puffs", locale: locale)
		case "nebule": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") nebules", locale: locale)
		case "injection": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") injections", locale: locale)
		case "tablespoon": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") tablespoons", locale: locale)
		case "pen": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") pens", locale: locale)
		case "inhaler": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") inhalers", locale: locale)
		case "vial": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") vials", locale: locale)
		case "patch": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") patches", locale: locale)
		case "application": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") applications", locale: locale)
		case "spray": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") sprays", locale: locale)
		case "strip": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") strips", locale: locale)
		case "film": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") films", locale: locale)
		case "dose": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") doses", locale: locale)
		case "ampule": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") ampules", locale: locale)
		case "bowl": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") bowls", locale: locale)
		case "joint": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") joints", locale: locale)
		case "dab": phrase = String(localized: "\(displayedAmount, specifier: "%.15g") dabs", locale: locale)
		default: phrase = "\(displayedAmount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) \(rawValue)"
		}
		return preservingCountPrecision(in: phrase, amount: displayedAmount, locale: locale)
	}

	/// Preserve native plural selection, repairing only a numeric token that lost precision.
	private static func preservingCountPrecision(in phrase: String, amount: Double, locale: Locale) -> String {
		guard amount.isFinite else { return phrase }
		let probe = String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), amount)
		guard Double(probe) != amount else { return phrase }

		let renderedCount = String(format: "%.15g", locale: locale, amount)
		guard let range = phrase.range(of: renderedCount, options: .literal),
			phrase[range.upperBound...].range(of: renderedCount, options: .literal) == nil else {
			return phrase
		}
		var result = phrase
		result.replaceSubrange(range, with: amount.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2))))
		return result
	}

	var quickLogAccessibilityLabel: String {
		let quantity = Self.localizedAmount(prescribedDoseAmount ?? 1, unit: prescribedUnit ?? "dose")
		return "\(String(localized: "Log Dose")): \(displayName), \(quantity)"
	}

	func canTake(at date: Date) -> Bool {
		guard let nextDoseDate else {
			return payloadCanTakeNow
		}

		return nextDoseDate <= date
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case displayName
		case quantity
		case prescribedDoseAmount
		case prescribedUnit
		case payloadCanTakeNow = "canTakeNow"
		case nextDoseDate
		case lowStock
		case refillSoon
		case statusMessage
	}
}

extension WatchMedication: Equatable {
	static func == (lhs: WatchMedication, rhs: WatchMedication) -> Bool {
		lhs.id == rhs.id
	}
}

extension WatchMedication: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}

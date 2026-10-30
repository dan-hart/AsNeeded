import ANModelKit
import Foundation

// Presentation only: ANModelKit raw values and clinical unit identity remain unchanged.
extension ANUnitConcept {
	var localizedDisplayName: String {
		switch self {
		case .milligram: return String(localized: "Milligram")
		case .gram: return String(localized: "Gram")
		case .microgram: return String(localized: "Microgram")
		case .unit: return String(localized: "Unit")
		case .tablet: return String(localized: "Tablet")
		case .capsule: return String(localized: "Capsule")
		case .chewable: return String(localized: "Chewable")
		case .lozenge: return String(localized: "Lozenge")
		case .suppository: return String(localized: "Suppository")
		case .milliliter: return String(localized: "Milliliter")
		case .liter: return String(localized: "Liter")
		case .teaspoon: return String(localized: "Teaspoon")
		case .drop: return String(localized: "Drop")
		case .sachet: return String(localized: "Sachet")
		case .puff: return String(localized: "Puff")
		case .nebule: return String(localized: "Nebule")
		case .injection: return String(localized: "Injection")
		case .tablespoon: return String(localized: "Tablespoon")
		case .pen: return String(localized: "Pen")
		case .inhaler: return String(localized: "Inhaler")
		case .vial: return String(localized: "Vial")
		case .patch: return String(localized: "Patch")
		case .application: return String(localized: "Application")
		case .spray: return String(localized: "Spray")
		case .strip: return String(localized: "Strip")
		case .film: return String(localized: "Film")
		case .dose: return String(localized: "Dose")
		case .ampule: return String(localized: "Ampule")
		case .bowl: return String(localized: "Bowl")
		case .joint: return String(localized: "Joint")
		case .dab: return String(localized: "Dab")
		}
	}
	var localizedAbbreviation: String {
		switch self {
		case .milligram: return String(localized: "mg")
		case .gram: return String(localized: "g")
		case .microgram: return String(localized: "mcg")
		case .unit: return String(localized: "unit")
		case .tablet: return String(localized: "tab")
		case .capsule: return String(localized: "cap")
		case .chewable: return String(localized: "chew")
		case .lozenge: return String(localized: "loz")
		case .suppository: return String(localized: "supp")
		case .milliliter: return String(localized: "mL")
		case .liter: return String(localized: "L")
		case .teaspoon: return String(localized: "tsp")
		case .drop: return String(localized: "gtt")
		case .sachet: return String(localized: "sach")
		case .puff: return String(localized: "puff")
		case .nebule: return String(localized: "neb")
		case .injection: return String(localized: "inj")
		case .tablespoon: return String(localized: "tbsp")
		case .pen: return String(localized: "pen")
		case .inhaler: return String(localized: "inh")
		case .vial: return String(localized: "vial")
		case .patch: return String(localized: "patch")
		case .application: return String(localized: "app")
		case .spray: return String(localized: "spr")
		case .strip: return String(localized: "strip")
		case .film: return String(localized: "film")
		case .dose: return String(localized: "dose")
		case .ampule: return String(localized: "amp")
		case .bowl: return String(localized: "bowl")
		case .joint: return String(localized: "joint")
		case .dab: return String(localized: "dab")
		}
	}
	var localizedClinicalDescription: String {
		switch self {
		case .milligram: return String(localized: "A metric unit of mass commonly used for medication dosing.")
		case .gram: return String(localized: "A metric unit of mass, used for larger medication doses.")
		case .microgram: return String(localized: "A small metric unit of mass for precise dosing.")
		case .unit: return String(localized: "A standardized quantity used for some biological medications.")
		case .tablet: return String(localized: "Solid oral medication, typically swallowed whole or split.")
		case .capsule: return String(localized: "Solid oral medication in a gelatin shell.")
		case .chewable: return String(localized: "A tablet designed to be chewed before swallowing.")
		case .lozenge: return String(localized: "A medicated tablet dissolving slowly in the mouth.")
		case .suppository: return String(localized: "Solid medication inserted into the rectum, vagina, or urethra.")
		case .milliliter: return String(localized: "A metric unit of volume for liquid medications.")
		case .liter: return String(localized: "A metric unit for larger liquid medication volumes.")
		case .teaspoon: return String(localized: "A small volume, approximately 5 mL, often used in pediatrics.")
		case .drop: return String(localized: "A single drop, used for eye, ear, or nasal medications.")
		case .sachet: return String(localized: "A small packet containing powder or granules.")
		case .puff: return String(localized: "A single actuation of an inhaler.")
		case .nebule: return String(localized: "A unit-dose container for nebulizer medications.")
		case .injection: return String(localized: "A dose delivered via needle into muscle, vein, or subcutaneous tissue.")
		case .tablespoon: return String(localized: "A household volume measurement, approximately 15 mL.")
		case .pen: return String(localized: "A pre-filled injection device, commonly used for insulin or biologics.")
		case .inhaler: return String(localized: "A dose delivered via dry powder inhaler device.")
		case .vial: return String(localized: "A small bottle for injectable or inhalation medications.")
		case .patch: return String(localized: "A medicated adhesive applied to the skin.")
		case .application: return String(localized: "A single use of a topical product (cream, ointment, gel, etc.).")
		case .spray: return String(localized: "A single metered dose delivered as a spray.")
		case .strip: return String(localized: "A thin film placed in the mouth for absorption.")
		case .film: return String(localized: "A medicated film for buccal or sublingual absorption.")
		case .dose: return String(localized: "A general dosage unit when no specific type applies.")
		case .ampule: return String(localized: "A sealed glass container for a single dose of medication.")
		case .bowl: return String(localized: "A measured amount of cannabis flower consumed via pipe or water pipe.")
		case .joint: return String(localized: "A cannabis cigarette containing a measured amount of cannabis flower.")
		case .dab: return String(localized: "A concentrated cannabis extract consumed via vaporization or dabbing.")
		}
	}
	/// Preserve compact SI symbols; counted non-SI units need native plural selection.
	func localizedCompactAmount(for amount: Double, locale: Locale = .current) -> String {
		switch self {
		case .milligram, .gram, .microgram, .milliliter, .liter:
			let displayedAmount = amount.truncatingRemainder(dividingBy: 1) == 0 ? amount : (amount * 100).rounded() / 100
			let quantity = displayedAmount.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
			return String(localized: "\(quantity) \(localizedAbbreviation)", locale: locale)
		default:
			return localizedAmount(for: amount, locale: locale)
		}
	}

	/// A complete quantity-and-unit phrase so catalog plural rules can use the actual quantity.
	func localizedAmount(for amount: Double, locale: Locale = .current) -> String {
		// Match the existing two-decimal presentation while keeping a numeric plural argument.
		let displayedAmount = amount.truncatingRemainder(dividingBy: 1) == 0 ? amount : (amount * 100).rounded() / 100
		let phrase: String
		switch self {
		case .milligram: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") milligrams", locale: locale)
		case .gram: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") grams", locale: locale)
		case .microgram: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") micrograms", locale: locale)
		case .unit: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") units", locale: locale)
		case .tablet: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") tablets", locale: locale)
		case .capsule: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") capsules", locale: locale)
		case .chewable: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") chewables", locale: locale)
		case .lozenge: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") lozenges", locale: locale)
		case .suppository: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") suppositories", locale: locale)
		case .milliliter: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") milliliters", locale: locale)
		case .liter: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") liters", locale: locale)
		case .teaspoon: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") teaspoons", locale: locale)
		case .drop: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") drops", locale: locale)
		case .sachet: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") sachets", locale: locale)
		case .puff: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") puffs", locale: locale)
		case .nebule: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") nebules", locale: locale)
		case .injection: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") injections", locale: locale)
		case .tablespoon: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") tablespoons", locale: locale)
		case .pen: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") pens", locale: locale)
		case .inhaler: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") inhalers", locale: locale)
		case .vial: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") vials", locale: locale)
		case .patch: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") patches", locale: locale)
		case .application: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") applications", locale: locale)
		case .spray: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") sprays", locale: locale)
		case .strip: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") strips", locale: locale)
		case .film: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") films", locale: locale)
		case .dose: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") doses", locale: locale)
		case .ampule: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") ampules", locale: locale)
		case .bowl: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") bowls", locale: locale)
		case .joint: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") joints", locale: locale)
		case .dab: phrase = String(localized: "\(displayedAmount, specifier: "%.15g") dabs", locale: locale)
		}
		return preservingCountPrecision(in: phrase, amount: displayedAmount, locale: locale)
	}
	/// Preserve native plural selection, repairing only a numeric token that lost precision.
	private func preservingCountPrecision(in phrase: String, amount: Double, locale: Locale) -> String {
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

}

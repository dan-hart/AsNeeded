import ANModelKit
import CoreText
import Foundation
import Testing
@testable import AsNeeded

struct LocalizationResourceTests {
	private static let locales = ["ar", "bg", "ca", "cs", "da", "de", "el", "en", "en-AU", "en-GB", "es", "es-419", "fa", "fi", "fr", "fr-CA", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-HK", "zh-Hans", "zh-Hant"]

	@Test(arguments: locales)
	func everyShippingSurfaceHasLocalizedResources(_ locale: String) throws {
		let app = Bundle.main.bundleURL
		let bundles = [app,
			app.appendingPathComponent("PlugIns/AsNeededWidgetExtension.appex"),
			app.appendingPathComponent("Watch/WristAsNeeded Watch App.app")]
		let keys = ["Close", "Demo Mode", "Dose logged", "Dose not logged", "Within saved guidance",
			"Within saved limits", "Review before logging", "Medications Unavailable", "Check recorded timing and open the dose form."]
		for url in bundles {
			let resources = try #require(Bundle(url: url.appendingPathComponent("\(locale).lproj")),
				"Missing localization bundle for \(locale) in \(url.lastPathComponent)")
			for key in keys {
				let value = resources.localizedString(forKey: key, value: "__MISSING_TRANSLATION__", table: "Localizable")
				#expect(value != "__MISSING_TRANSLATION__", "\(locale): \(key) missing from \(url.lastPathComponent)")
				#expect(!value.isEmpty)
			}
			if !locale.hasPrefix("en") {
				#expect(resources.localizedString(forKey: "Demo Mode", value: nil, table: "Localizable") != "Demo Mode")
			}
		}
	}

	@Test
	func fullQuantityUsesNativeSingularPluralAndDecimalFormatting() throws {
		let url = Bundle.main.bundleURL.appendingPathComponent("fr.lproj")
		let resources = try #require(Bundle(url: url))
		let locale = Locale(identifier: "fr")
		let one = 1.0
		let two = 2.0
		let fraction = 0.5
		let singular = String(localized: "\(one, specifier: "%.15g") tablets", bundle: resources, locale: locale)
		let plural = String(localized: "\(two, specifier: "%.15g") tablets", bundle: resources, locale: locale)
		let fractional = String(localized: "\(fraction, specifier: "%.15g") tablets", bundle: resources, locale: locale)
		#expect(singular.contains("comprimé"))
		#expect(!singular.contains("comprimés"))
		#expect(plural.contains("comprimés"))
		#expect(fractional.contains("0,5"))
		#expect(!fractional.contains("%"))
	}


	@Test("Counted compact units retain native English singular and plural forms")
	func compactCountedUnitsUseNativePluralResources() throws {
		let resources = try #require(Bundle(url: Bundle.main.bundleURL.appendingPathComponent("en.lproj")))
		let locale = Locale(identifier: "en_US")
		let one = 1.0
		let two = 2.0
		let singular = String(localized: "\(one, specifier: "%.15g") tablets", bundle: resources, locale: locale)
		let plural = String(localized: "\(two, specifier: "%.15g") tablets", bundle: resources, locale: locale)
		#expect(singular == "1 tablet")
		#expect(plural == "2 tablets")
		#expect(ANUnitConcept.tablet.localizedCompactAmount(for: two, locale: locale) == ANUnitConcept.tablet.localizedAmount(for: two, locale: locale))
	}

	@Test
	func multipleCountsUseIndependentNativePlurals() throws {
		let resources = try #require(Bundle(url: Bundle.main.bundleURL.appendingPathComponent("en.lproj")))
		let locale = Locale(identifier: "en")
		for (medications, events) in [(1, 2), (2, 1)] {
			let value = String(localized: "Data imported successfully\n\(medications) medications, \(events) events", bundle: resources, locale: locale)
			let expectedMedication = medications == 1 ? "1 medication," : "2 medications,"
			let expectedEvents = events == 1 ? "1 event" : "2 events"
			#expect(value.contains(expectedMedication))
			#expect(value.hasSuffix(expectedEvents))
			#expect(!value.contains("%"))
		}
	}

	@Test("RTL stock field places its category label visually to the right of the quantity", arguments: ["ar", "he", "fa"])
	func rtlRemainingFieldPreservesVisualOrder(_ locale: String) throws {
		let resources = try #require(Bundle(url: Bundle.main.bundleURL.appendingPathComponent("\(locale).lproj")))
		let label = String(localized: "Remaining", bundle: resources, locale: Locale(identifier: locale))
		let quantity = "14 tablets"
		let text = String(localized: "\(label): \(quantity)", bundle: resources, locale: Locale(identifier: locale))
		let labelRange = (text as NSString).range(of: label)
		let quantityRange = (text as NSString).range(of: quantity)
		try #require(labelRange.location != NSNotFound)
		try #require(quantityRange.location != NSNotFound)
		#expect(label != "Remaining")

		// Natural paragraph direction must come from the resource; forcing RTL here hides the regression.
		let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
		let attributed = NSAttributedString(string: text, attributes: [
			NSAttributedString.Key(kCTFontAttributeName as String): font
		])
		let line = CTLineCreateWithAttributedString(attributed)
		let labelX = CTLineGetOffsetForStringIndex(line, labelRange.location, nil)
		let quantityX = CTLineGetOffsetForStringIndex(line, quantityRange.location, nil)
		#expect(labelX > quantityX, "The RTL category label must appear to the right of its quantity")
	}

	@Test(arguments: locales)
	func systemPermissionDescriptionsAreLocalized(_ locale: String) throws {
		let url = Bundle.main.bundleURL.appendingPathComponent("\(locale).lproj")
		let resources = try #require(Bundle(url: url))
		for key in ["NSDocumentsFolderUsageDescription", "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription", "Quick log medication"] {
			let value = resources.localizedString(forKey: key, value: "__MISSING_TRANSLATION__", table: "InfoPlist")
			#expect(value != "__MISSING_TRANSLATION__", "\(locale): system text \(key) is missing")
			#expect(!value.isEmpty)
		}
	}
}

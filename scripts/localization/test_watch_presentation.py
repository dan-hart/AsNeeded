"""Standalone Foundation model regression proof; no app/UI test target required."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("swiftc"), "Swift compiler is optional for standalone Watch proof")
class WatchPresentationTests(unittest.TestCase):
	def test_native_polish_quantity_forms_and_legacy_status_boundaries(self):
		model = Path(__file__).resolve().parents[2] / "WristAsNeeded Watch App" / "WatchMedication.swift"
		with tempfile.TemporaryDirectory(prefix="asneeded-watch-presentation-") as directory:
			root = Path(directory)
			contents = root / "Proof.app" / "Contents"
			resources = contents / "Resources" / "pl.lproj"
			resources.mkdir(parents=True)
			binary = contents / "MacOS" / "Proof"
			binary.parent.mkdir()
			(contents / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.asneeded.watch-presentation", "CFBundleExecutable": "Proof", "CFBundleDevelopmentRegion": "pl"}))
			(resources / "Localizable.stringsdict").write_bytes(plistlib.dumps({"%.15g tablets": {
				"NSStringLocalizedFormatKey": "%#@quantity@", "quantity": {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType", "NSStringFormatValueTypeKey": "g",
				"one": "%.15g tabletka", "few": "%.15g tabletki", "many": "%.15g tabletek", "other": "%.15g tabletki"}}}))
			(resources / "Localizable.strings").write_bytes(plistlib.dumps({
				"Review saved limits": "Przejrzyj zapisane limity",
				"Log Dose": "Zapisz dawkę",
				"Saved limits met based on logged doses. Follow your prescription and care instructions.": "Zapisane limity spełnione.",
				"Next saved window: %@. Follow your prescription and care instructions.": "Następne okno: %@."}))
			harness = root / "Proof.swift"
			harness.write_text(r'''
import Foundation
@main struct Proof {
	static func main() throws {
		let locale = Locale(identifier: "pl")
		precondition(WatchMedication.localizedAmount(1, unit: "tablet", locale: locale) == "1 tabletka")
		precondition(WatchMedication.localizedAmount(2, unit: "tablet", locale: locale) == "2 tabletki")
		precondition(WatchMedication.localizedAmount(5, unit: "tablet", locale: locale) == "5 tabletek")
		let fractional = WatchMedication.localizedAmount(1.23456, unit: "tablet", locale: locale)
		precondition(fractional.replacingOccurrences(of: ",", with: ".") == "1.23 tabletki")
		precondition(WatchMedication.localizedAmount(0.1, unit: "tablet", locale: locale).contains("tabletki"))
		precondition(WatchMedication.localizedAmount(2.5, unit: "custom raw unit", locale: locale).hasSuffix(" custom raw unit"))
		let identifier = UUID()
		let base: [String: Any] = ["id": identifier.uuidString, "displayName": "Medication 名称", "quantity": 12.345,
			"prescribedDoseAmount": 2.0, "prescribedUnit": "tablet", "canTakeNow": true]
		var past = base
		past["nextDoseDate"] = Date.distantPast
		past["statusMessage"] = "old phone locale"
		let eligible = WatchMedication(from: past)
		precondition(eligible.statusMessage == "Zapisane limity spełnione.")
		precondition(eligible.canTake(at: Date()))
		var future = base
		future["nextDoseDate"] = Date.distantFuture
		future["statusMessageKey"] = ""
		let pending = WatchMedication(from: future)
		precondition(pending.statusMessage?.hasPrefix("Następne okno:") == true)
		precondition(!pending.canTake(at: Date()))
		var modern = base
		modern["statusMessageKey"] = "Review saved limits"
		modern["statusMessage"] = "different phone language"
		precondition(WatchMedication(from: modern).statusMessage == "Przejrzyj zapisane limity")
		var legacy = base
		legacy["statusMessage"] = "unknown foreign companion message"
		precondition(WatchMedication(from: legacy).statusMessage == "unknown foreign companion message")
		precondition(eligible.id == identifier && eligible.displayName == "Medication 名称")
		precondition(eligible.quantity == 12.345 && eligible.prescribedDoseAmount == 2 && eligible.prescribedUnit == "tablet")
		precondition(eligible.quickLogAccessibilityLabel.contains("Zapisz dawkę"))
		precondition(eligible.quickLogAccessibilityLabel.contains("Medication 名称"))
		precondition(eligible.quickLogAccessibilityLabel.contains("2 tabletki"))
		let roundTrip = try JSONDecoder().decode(WatchMedication.self, from: JSONEncoder().encode(eligible))
		precondition(roundTrip.quantity == 12.345 && roundTrip.prescribedUnit == "tablet")
		print("Watch presentation proof passed")
	}
}
''')
			subprocess.run(["swiftc", "-module-cache-path", str(root / "module-cache"), str(model), str(harness), "-o", str(binary)], check=True, capture_output=True, text=True)
			result = subprocess.run([str(binary), "-AppleLanguages", "(pl)", "-AppleLocale", "pl_PL"], check=True, capture_output=True, text=True)
			self.assertIn("Watch presentation proof passed", result.stdout)


	def test_extreme_quantity_precision_preserves_native_plural_and_ambiguous_literals(self):
		model = Path(__file__).resolve().parents[2] / "WristAsNeeded Watch App" / "WatchMedication.swift"
		with tempfile.TemporaryDirectory(prefix="asneeded-quantity-precision-") as directory:
			root = Path(directory)
			contents = root / "Proof.app" / "Contents"
			resources = contents / "Resources"
			binary = contents / "MacOS" / "Proof"
			binary.parent.mkdir(parents=True)
			(contents / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.asneeded.quantity-precision", "CFBundleExecutable": "Proof", "CFBundleDevelopmentRegion": "en"}))
			forms = {
				"en": {"one": "%.15g tablet", "other": "%.15g tablets"},
				"de": {"one": "%.15g Tablette", "other": "%.15g Tabletten"},
				"ar": {"zero": "%.15g قرص", "one": "%.15g قرص", "two": "%.15g قرصان", "few": "%.15g أقراص", "many": "%.15g قرصًا", "other": "%.15g قرص"},
				"ja": {"other": "%.15g錠"},
				"ru": {"one": "%.15g таблетка", "few": "%.15g таблетки", "many": "%.15g таблеток", "other": "%.15g таблетки"},
			}
			for language, plural in forms.items():
				folder = resources / (language + ".lproj")
				folder.mkdir(parents=True)
				def record(values):
					return {"NSStringLocalizedFormatKey": "%#@quantity@", "quantity": {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType", "NSStringFormatValueTypeKey": "g", **values}}
				(folder / "Localizable.stringsdict").write_bytes(plistlib.dumps({
					"%.15g tablets": record(plural),
					"%.15g capsules": record({"one": "literal 2026 / capsules %.15g", "other": "literal 2026 / capsules %.15g"}),
					"%.15g doses": record({"one": "100,000,000,000,000 | %.15g doses", "other": "100,000,000,000,000 | %.15g doses"}),
				}))
			harness = root / "Proof.swift"
			harness.write_text(r'''
import Foundation
@main struct Proof {
	static func main() {
		let identifier = CommandLine.arguments[1]
		let locale = Locale(identifier: identifier)
		for amount in [0.0, 1, 2, 3, 5, 11, 100, 0.5, 1.25, 1234.56, 99999999999999.5, -2] {
			let original = String(localized: "\(amount, specifier: "%.15g") tablets", locale: locale)
			precondition(WatchMedication.localizedAmount(amount, unit: "tablet", locale: locale) == original, "Ordinary output changed")
		}
		let threshold = 10000000000000.01
		let thresholdText = threshold.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
		precondition(WatchMedication.localizedAmount(threshold, unit: "tablet", locale: locale).contains(thresholdText), "Threshold fraction lost")
		let separator = identifier.hasPrefix("ja") ? "" : " "
		let suffix = identifier.hasPrefix("de") ? "Tabletten" : identifier.hasPrefix("ar") ? "قرص" : identifier.hasPrefix("ja") ? "錠" : identifier.hasPrefix("ru") ? "таблетки" : "tablets"
		for amount in [100000000000000.5, -100000000000000.5] {
			let full = amount.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
			let actual = WatchMedication.localizedAmount(amount, unit: "tablet", locale: locale)
			precondition(actual == full + separator + suffix, "Extreme fraction lost: " + actual)
			precondition(WatchMedication.localizedAmount(amount, unit: "capsule", locale: locale) == "literal 2026 / capsules " + full, "Reordered numeric replacement failed")
		}
		let largest = Double.greatestFiniteMagnitude
		let full = largest.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
		precondition(WatchMedication.localizedAmount(largest, unit: "tablet", locale: locale).hasPrefix(full), "Largest finite quantity lost precision")
		if identifier == "en_US" {
			let amount = 100000000000000.5
			let native = String(localized: "\(amount, specifier: "%.15g") doses", locale: locale)
			precondition(WatchMedication.localizedAmount(amount, unit: "dose", locale: locale) == native, "Ambiguous literal was changed")
		}
		print("Quantity precision proof passed: " + identifier)
	}
}
''')
			subprocess.run(["swiftc", "-module-cache-path", str(root / "module-cache"), str(model), str(harness), "-o", str(binary)], check=True, capture_output=True, text=True)
			for language, locale in [("en", "en_US"), ("de", "de_DE"), ("ar", "ar_EG"), ("ar", "ar_SA"), ("ja", "ja_JP"), ("ru", "ru_RU")]:
				with self.subTest(locale=locale):
					result = subprocess.run([str(binary), locale, "-AppleLanguages", "(" + language + ")", "-AppleLocale", locale], capture_output=True, text=True)
					self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
					self.assertIn("Quantity precision proof passed", result.stdout)


if __name__ == "__main__":
	unittest.main()

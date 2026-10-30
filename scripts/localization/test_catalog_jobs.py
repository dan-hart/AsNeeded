import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import catalog_jobs as subject
import translate_catalog as translation


def unit(value):
	return {"stringUnit": {"state": "translated", "value": value}}


class CatalogJobsTests(unittest.TestCase):
	def fixture(self):
		return {"Localizable.xcstrings": {"sourceLanguage": "en", "version": "1.0", "strings": {
			"Save": {"comment": "Retain this", "extractionState": "manual", "localizations": {"en": unit("Save"), "de": unit("Speichern")}},
			"%g tablets": {"localizations": {"de": unit("%g Tabletten")}},
			"AsNeeded": {"localizations": {"de": unit("AsNeeded")}},
			"": {"localizations": {"de": unit("")}}}},
			"InfoPlist.xcstrings": {"sourceLanguage": "en", "version": "1.0", "strings": {
				"NSCameraUsageDescription": {"comment": "Privacy", "localizations": {"en": unit("Scan a medication barcode.")}}}}}

	def staging(self, jobs):
		staged = {}
		for job in jobs:
			values = {}
			for entry in job["entries"]:
				if job["locale"] == "en" or entry.get("allow_english"):
					value = entry["source"]
				else:
					try:
						translation.validate_value(entry, entry.get("existing"), job["locale"])
						value = entry["existing"]
					except ValueError:
						value = "DE " + entry["source"]
				values[entry["key"]] = value
			staged[job["locale"]] = {"locale": job["locale"], "job_sha256": translation.job_digest(job), "translations": values,
				"plural_entries": [{"key": entry["key"], "group": entry["plural_group"], "form": entry["plural_form"]} for entry in job["entries"] if "plural_group" in entry]}
		return staged

	def test_prepare_uses_infoplist_english_values_and_opaque_keys(self):
		mapping, jobs = subject.prepare(self.fixture())
		self.assertEqual(set(mapping["locales"]), {"en", "de"})
		for job in jobs:
			self.assertTrue(all(len(entry["key"]) == 25 for entry in job["entries"]))
			self.assertIn("Scan a medication barcode.", [entry["source"] for entry in job["entries"]])
			self.assertNotIn("NSCameraUsageDescription", [entry["source"] for entry in job["entries"]])
			forms = [entry["plural_form"] for entry in job["entries"] if "plural_group" in entry]
			self.assertEqual(set(forms), {"one", "other"})

	def test_merge_native_plurals_preserves_metadata_and_existing_translation(self):
		original = self.fixture()
		mapping, jobs = subject.prepare(original)
		candidate = subject.merge(mapping, jobs, self.staging(jobs))
		self.assertEqual(original, self.fixture())
		save = candidate["Localizable.xcstrings"]["strings"]["Save"]
		self.assertEqual(save["comment"], "Retain this")
		self.assertEqual(save["extractionState"], "manual")
		self.assertEqual(save["localizations"]["de"], unit("Speichern"))
		plural = candidate["Localizable.xcstrings"]["strings"]["%g tablets"]["localizations"]["en"]["variations"]["plural"]
		self.assertEqual(plural["one"]["stringUnit"]["value"], "%g tablet")
		self.assertEqual(plural["other"]["stringUnit"]["value"], "%g tablets")
		self.assertEqual(candidate["Localizable.xcstrings"]["strings"][""]["localizations"]["en"]["stringUnit"]["value"], "")

	def test_merge_marks_verified_unchanged_scalars_translated_preserving_metadata(self):
		for state in ["new", "needs_review"]:
			with self.subTest(state=state):
				catalogs = self.fixture()
				save = catalogs["Localizable.xcstrings"]["strings"]["Save"]
				for locale in ["en", "de"]:
					save["localizations"][locale]["stringUnit"].update(state=state, note="Retain leaf metadata")
				original = copy.deepcopy(catalogs)
				mapping, jobs = subject.prepare(catalogs)
				candidate = subject.merge(mapping, jobs, self.staging(jobs))
				result = candidate["Localizable.xcstrings"]["strings"]["Save"]
				self.assertEqual(result["comment"], "Retain this")
				self.assertEqual(result["extractionState"], "manual")
				for locale, value in [("en", "Save"), ("de", "Speichern")]:
					self.assertEqual(result["localizations"][locale]["stringUnit"], {
						"state": "translated", "value": value, "note": "Retain leaf metadata"})
				self.assertEqual(catalogs, original)

	def test_merge_rejects_missing_locale_or_modified_job(self):
		mapping, jobs = subject.prepare(self.fixture())
		with self.assertRaisesRegex(ValueError, "every catalog locale"):
			subject.merge(mapping, jobs[:-1], self.staging(jobs))
		changed = copy.deepcopy(jobs)
		changed[0]["entries"][0]["source"] = "Changed"
		with self.assertRaisesRegex(ValueError, "job changed"):
			subject.merge(mapping, changed, self.staging(changed))

	def test_substitution_variation_paths_survive_prepare_merge(self):
		catalogs = self.fixture()
		catalogs["Localizable.xcstrings"]["strings"]["count"] = {"localizations": {"en": {
			"stringUnit": {"state": "translated", "value": "%#@count@"},
			"substitutions": {"count": {"argNum": 1, "formatSpecifier": "lld", "variations": {"plural": {"one": unit("%lld item"), "other": unit("%lld items")}}}}}}}
		mapping, jobs = subject.prepare(catalogs)
		# The format-only native substitution wrapper is allowed verbatim.
		candidate = subject.merge(mapping, jobs, self.staging(jobs))
		substitution = candidate["Localizable.xcstrings"]["strings"]["count"]["localizations"]["de"]["substitutions"]["count"]
		self.assertEqual(substitution["argNum"], 1)
		self.assertEqual(substitution["formatSpecifier"], "lld")
		self.assertEqual(set(substitution["variations"]["plural"]), {"one", "other"})

	def test_reconcile_stringsdata_and_xliff(self):
		with tempfile.TemporaryDirectory() as directory:
			path = Path(directory) / "export.xliff"
			path.write_text('<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2"><file original="AsNeeded/InfoPlist.strings"><body><trans-unit id="CFBundleDisplayName"><source>As Needed</source></trans-unit></body></file></xliff>')
			extracted = subject.read_extracted([path])
			catalogs = subject.reconcile(self.fixture(), extracted)
			self.assertEqual(catalogs["InfoPlist.xcstrings"]["strings"]["CFBundleDisplayName"]["localizations"]["en"], unit("As Needed"))

	def test_count_detection_does_not_pluralize_indexes_or_percentages(self):
		for source in ["%lld", "%lld: No doses", "Usage progress: %lld%% used"]:
			self.assertFalse(subject.count_phrase(source), source)
		for source in ["%g tablets", "%lld days remaining", "You have %lld medications: %@", "%lld characters", "%lldd"]:
			self.assertTrue(subject.count_phrase(source), source)
		self.assertEqual(subject.singular("Take %lld tablets with other medications"), "Take %lld tablet with other medications")

	def test_singular_preserves_title_case(self):
		self.assertEqual(subject.singular("%lld Days"), "%lld Day")
		self.assertEqual(subject.singular("%1$@ · %2$lld Days"), "%1$@ · %2$lld Day")

	def test_review_can_allow_singular_cognate_without_allowing_plural(self):
		catalogs = self.fixture()
		catalogs["Localizable.xcstrings"]["strings"]["%g vials"] = {}
		reviews = {"de": {"Localizable.xcstrings": {"%g vials": {"%g vial": "Reviewed singular cognate"}}}}
		mapping, jobs = subject.prepare(catalogs, reviews)
		entries = [entry for job in jobs if job["locale"] == "de" for entry in job["entries"] if entry["source"] in ["%g vial", "%g vials"]]
		self.assertEqual(len(entries), 2)
		self.assertTrue(next(entry for entry in entries if entry["source"] == "%g vial").get("allow_english"))
		self.assertFalse(next(entry for entry in entries if entry["source"] == "%g vials").get("allow_english"))
		with self.assertRaisesRegex(ValueError, "exact source variant"):
			subject.prepare(catalogs, {"de": {"Localizable.xcstrings": {"%g vials": "Too broad"}}})

	def test_semantic_keys_use_english_region_fallback_without_renaming(self):
		catalogs = self.fixture()
		catalogs["Localizable.xcstrings"]["strings"]["healthkit.auth.detail.authorized"] = {"extractionState": "stale", "localizations": {
			"en-GB": unit("AsNeeded is connected to Apple Health."), "en-AU": unit("Australian fallback")}}
		mapping, jobs = subject.prepare(catalogs)
		for job in jobs:
			entries = [entry for entry in job["entries"] if entry["source"] == "AsNeeded is connected to Apple Health."]
			self.assertEqual(len(entries), 1)
			self.assertEqual(mapping["entries"][entries[0]["key"]]["key"], "healthkit.auth.detail.authorized")
		self.assertEqual(mapping["templates"]["en"]["Localizable.xcstrings"]["healthkit.auth.detail.authorized"], unit("AsNeeded is connected to Apple Health."))

	def test_english_source_priority_and_unresolved_semantic_key_failure(self):
		entry = {"localizations": {"en-AU": unit("AU"), "en-GB": unit("GB"), "en-US": unit("US"), "en": unit("EN")}}
		self.assertEqual(subject.english_source_node("semantic.id", entry), unit("EN"))
		del entry["localizations"]["en"]
		self.assertEqual(subject.english_source_node("semantic.id", entry), unit("US"))
		for key in ["healthkit.auth.detail.authorized", "settings_sync_state", "lastDose", "NSCameraUsageDescription", "MedicationName", "JSONData"]:
			with self.assertRaisesRegex(ValueError, "no English display source"):
				subject.english_source_node(key, {})
		self.assertEqual(subject.english_source_node("Log Dose", {}), unit("Log Dose"))

	def test_collects_actual_english_regional_leaves_and_literal_display_key(self):
		catalogs = self.fixture()
		key = "Find trusted healthcare information from these reputable organizations."
		gb = "Find trusted healthcare information from these reputable organisations."
		catalogs["Localizable.xcstrings"]["strings"][key] = {"localizations": {"en-GB": unit(gb), "fr": unit(key)}}
		catalogs["Localizable.xcstrings"]["strings"]["settings.colour.label"] = {"localizations": {
			"en": unit("Colour"), "en-US": unit("Color"), "en-GB": unit("Colour"), "en-AU": unit("Colour choice"), "fr": unit("Color")}}
		mapping, jobs = subject.prepare(catalogs)
		entries = next(job for job in jobs if job["locale"] == "fr")["entries"]
		entry = next(entry for entry in entries if entry["source"] == gb)
		self.assertEqual(entry["english_variants"], [key])
		with self.assertRaisesRegex(ValueError, "untranslated English"):
			translation.validate_value(entry, entry["existing"], "fr")
		semantic = next(entry for entry in entries if entry["source"] == "Colour")
		self.assertEqual(semantic["english_variants"], ["Color", "Colour choice"])
		self.assertNotIn("settings.colour.label", semantic["english_variants"])

	def test_english_variant_plural_leaves_follow_native_path_and_other_fallback(self):
		item = {"localizations": {"en": {"variations": {"plural": {
			"one": unit("%g coloured tablet"), "other": unit("%g coloured tablets")}}},
			"en-US": {"variations": {"plural": {
				"one": unit("%g colored tablet"), "other": unit("%g colored tablets")}}}}}
		one = ("variations", "plural", "one", "stringUnit", "value")
		few = ("variations", "plural", "few", "stringUnit", "value")
		self.assertEqual(subject.english_variants("medication.colour", item, one, "%g coloured tablet", "ar"), ["%g colored tablet"])
		self.assertEqual(subject.english_variants("medication.colour", item, few, "%g coloured tablets", "ar"), ["%g colored tablets"])
		# A newly pluralized source can retain its actual plain regional English leaf.
		plain = {"localizations": {"en-US": unit("%g colored tablets")}}
		self.assertEqual(subject.english_variants("medication.colour", plain, one, "%g coloured tablet", "fr"), ["%g colored tablets"])

	def test_irregular_unit_and_backup_counts_get_native_plural_templates_for_all_locales(self):
		locales = ["ar", "bg", "ca", "cs", "da", "de", "el", "en", "en-AU", "en-GB", "es", "es-419", "fa", "fi", "fr", "fr-CA", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-HK", "zh-Hans", "zh-Hant"]
		sources = {"%.15g suppositories": "%.15g suppository", "%.15g patches": "%.15g patch", "%lld backups • %@": "%lld backup • %@"}
		catalogs = {"Localizable.xcstrings": {"sourceLanguage": "en", "strings": {
			source: {"localizations": {locale: unit(source) for locale in locales}} for source in sources}}}
		mapping, jobs = subject.prepare(catalogs)
		self.assertEqual(set(mapping["locales"]), set(locales))
		for locale in locales:
			for source, one in sources.items():
				with self.subTest(locale=locale, source=source):
					plurals = mapping["templates"][locale]["Localizable.xcstrings"][source]["variations"]["plural"]
					self.assertEqual(set(plurals), translation.plural_forms(locale))
					self.assertEqual(plurals["other"], unit(source))
					if "one" in plurals:
						self.assertEqual(plurals["one"], unit(one))
					for form, node in plurals.items():
						self.assertEqual(translation.placeholders(node["stringUnit"]["value"]), translation.placeholders(source))
		for job in jobs:
			translation.validate_job(job)

	def test_irregular_mapping_does_not_guess_other_nouns_or_change_unrelated_words(self):
		self.assertEqual(subject.singular("%lld patches with extra doses"), "%lld patch with extra doses")
		self.assertEqual(subject.singular("%lld suppositories with backup instructions"), "%lld suppository with backup instructions")
		for source in ["Apply patches to skin", "%lld matches", "%lld watches", "%lld: No backups"]:
			self.assertFalse(subject.count_phrase(source), source)
			self.assertEqual(subject.source_template(source, {}), unit(source))

	def test_known_multicount_templates_preserve_independent_arguments_in_every_locale(self):
		locales = ["ar", "bg", "ca", "cs", "da", "de", "el", "en", "en-AU", "en-GB", "es", "es-419", "fa", "fi", "fr", "fr-CA", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-HK", "zh-Hans", "zh-Hant"]
		keys = list(subject.MULTICOUNT)
		catalogs = {"Localizable.xcstrings": {"sourceLanguage": "en", "strings": {
			key: {"comment": "Keep outer metadata", "localizations": {locale: unit(key) for locale in locales}} for key in keys}}}
		mapping, jobs = subject.prepare(catalogs)
		self.assertEqual(len(keys), 4)
		for locale in locales:
			for key in keys:
				with self.subTest(locale=locale, key=key):
					template = mapping["templates"][locale]["Localizable.xcstrings"][key]
					wrapper, counts = subject.MULTICOUNT[key]
					self.assertEqual(template["stringUnit"]["value"], wrapper)
					# Derive original numeric argument positions independently of the template table.
					numeric_positions = [number for number, match in enumerate(translation.PERCENT.finditer(key), 1) if match[2] == "lld"]
					self.assertEqual([count["argNum"] for count in template["substitutions"].values()], numeric_positions)
					for name, number, one, other in counts:
						count = template["substitutions"][name]
						self.assertEqual(count["argNum"], number)
						self.assertEqual(count["formatSpecifier"], "lld")
						self.assertEqual(set(count["variations"]["plural"]), translation.plural_forms(locale))
						self.assertEqual(count["variations"]["plural"]["other"], unit(other))
						if "one" in count["variations"]["plural"]:
							self.assertEqual(count["variations"]["plural"]["one"], unit(one))
		# Count axes must select independently for 1/2 and 2/1, including object arg 1.
		english = mapping["templates"]["en"]["Localizable.xcstrings"][keys[0]]
		self.assertEqual(english["stringUnit"]["value"], "%1$@\n%2$#@medications@, %3$#@events@")
		for medications, events, expected in [(1, 2, ["%arg medication", "%arg events"]), (2, 1, ["%arg medications", "%arg event"])]:
			selected = [english["substitutions"][name]["variations"]["plural"]["one" if number == 1 else "other"]["stringUnit"]["value"] for name, number in [("medications", medications), ("events", events)]]
			self.assertEqual(selected, expected)
		candidate = subject.merge(mapping, jobs, self.staging(jobs))
		for key in keys:
			self.assertEqual(candidate["Localizable.xcstrings"]["strings"][key]["comment"], "Keep outer metadata")
			self.assertEqual(candidate["Localizable.xcstrings"]["strings"][key]["localizations"]["en"]["substitutions"], mapping["templates"]["en"]["Localizable.xcstrings"][key]["substitutions"])
		self.assertNotIn("substitutions", subject.source_template("Unrelated %lld widgets and %lld gadgets", {}))

	def test_multicount_leaf_variants_exclude_whole_key_and_existing_native_metadata_survives(self):
		key = "%@\n%lld medications, %lld events"
		catalogs = self.fixture()
		native = subject.multicount_template(key)
		native["substitutions"]["medications"]["comment"] = "Preserve native metadata"
		catalogs["Localizable.xcstrings"]["strings"][key] = {"localizations": {"en": native}}
		mapping, jobs = subject.prepare(catalogs)
		job = next(job for job in jobs if job["locale"] == "de")
		entries = [entry for entry in job["entries"] if mapping["entries"][entry["key"]]["key"] == key]
		for entry in entries:
			if "substitutions" in mapping["entries"][entry["key"]]["path"]:
				self.assertNotIn(key, entry.get("english_variants", []))
				self.assertNotIn("allow_english", entry)
		wrapper = next(entry for entry in entries if entry["source"] == "%1$@\n%2$#@medications@, %3$#@events@")
		self.assertTrue(wrapper["allow_english"])
		with tempfile.TemporaryDirectory() as directory, patch.object(translation.subprocess, "run", side_effect=AssertionError("provider must not run")):
			# No locale/provider text exists in this wrapper: its reviewed identity is sufficient.
			staged = translation.run({"locale": "de", "entries": [wrapper]}, Path(directory))
			self.assertEqual(staged["translations"][wrapper["key"]], wrapper["source"])
		candidate = subject.merge(mapping, jobs, self.staging(jobs))
		self.assertEqual(candidate["Localizable.xcstrings"]["strings"][key]["localizations"]["de"]["substitutions"]["medications"]["comment"], "Preserve native metadata")
		self.assertIsNone(subject.identity_reason("Found %1$#@medications@"))

	def shortcuts_fixture(self):
		groups = [
			["How much ${medication} have I taken today in ${applicationName}", "What's my daily usage of ${medication} in ${applicationName}", "Check my ${medication} usage today in ${applicationName}", "How many ${medication} today in ${applicationName}"],
			["List my medications in ${applicationName}", "Show my medications in ${applicationName}", "What medications do I have in ${applicationName}", "My medication list in ${applicationName}"],
			["Log medication in ${applicationName}", "Take medication with ${applicationName}", "Record dose in ${applicationName}", "Log ${medication} in ${applicationName}", "I took ${medication} in ${applicationName}"],
			["Tell me about ${medication} in ${applicationName}", "Get information about ${medication} in ${applicationName}", "What do I have for ${medication} in ${applicationName}", "Show me ${medication} details in ${applicationName}"],
			["What medications need refills in ${applicationName}", "Check my refill status in ${applicationName}", "Which medications are running low in ${applicationName}", "Do I need any refills in ${applicationName}"],
			["When can I take my medication in ${applicationName}", "When is my next dose in ${applicationName}", "When do I need to take ${medication} in ${applicationName}", "Check my next dose in ${applicationName}"]]
		locales = ["ar", "bg", "ca", "cs", "da", "de", "el", "en", "en-AU", "en-GB", "es", "es-419", "fa", "fi", "fr", "fr-CA", "he", "hi", "hr", "hu", "id", "it", "ja", "kk", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-HK", "zh-Hans", "zh-Hant"]
		return {"Localizable.xcstrings": {"sourceLanguage": "en", "version": "1.0", "strings": {"Inventory": {"localizations": {locale: unit("Inventory") for locale in locales}}}},
			"AppShortcuts.xcstrings": {"sourceLanguage": "en", "version": "1.0", "strings": {
				phrases[0]: {"extractionState": "extracted_with_value", "localizations": {"en": {"stringSet": {"state": "new", "values": phrases}}}} for phrases in groups}}}

	def test_shortcut_sets_prepare_25_phrases_and_merge_native_arrays_in_42_locales(self):
		catalogs = self.shortcuts_fixture()
		key = "Log medication in ${applicationName}"
		phrases = catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["en"]["stringSet"]["values"]
		catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["de"] = {"stringSet": {"state": "needs_review", "note": "Preserve set metadata", "values": ["DE " + value for value in phrases]}}
		original = copy.deepcopy(catalogs)
		mapping, jobs = subject.prepare(catalogs)
		self.assertEqual(len(jobs), 42)
		for job in jobs:
			entries = [entry for entry in job["entries"] if mapping["entries"][entry["key"]]["catalog"] == "AppShortcuts.xcstrings"]
			self.assertEqual(len(entries), 25)
			self.assertTrue(all(type(mapping["entries"][entry["key"]]["path"][-1]) is int for entry in entries))
		staged = self.staging(jobs)
		candidate = subject.merge(mapping, jobs, staged)
		self.assertEqual(catalogs, original)
		self.assertEqual(set(candidate["AppShortcuts.xcstrings"]["strings"]), set(catalogs["AppShortcuts.xcstrings"]["strings"]))
		for key, record in candidate["AppShortcuts.xcstrings"]["strings"].items():
			self.assertEqual(record["extractionState"], "extracted_with_value")
			count = len(catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["en"]["stringSet"]["values"])
			for locale in mapping["locales"]:
				string_set = record["localizations"][locale]["stringSet"]
				self.assertEqual(set(record["localizations"][locale]), {"stringSet"})
				self.assertEqual(string_set["state"], "translated")
				self.assertEqual(len(string_set["values"]), count)
				for identifier, path_record in mapping["entries"].items():
					if path_record["catalog"] == "AppShortcuts.xcstrings" and path_record["key"] == key:
						self.assertEqual(subject.at(record["localizations"][locale], path_record["path"]), staged[locale]["translations"][identifier])
		self.assertEqual(candidate["AppShortcuts.xcstrings"]["strings"]["Log medication in ${applicationName}"]["localizations"]["de"]["stringSet"]["note"], "Preserve set metadata")

	def test_shortcut_english_variants_match_only_compatible_phrase_index(self):
		catalogs = self.shortcuts_fixture()
		key = "List my medications in ${applicationName}"
		catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["en-GB"] = {"stringSet": {"state": "translated", "values": [key, "Display my medications in ${applicationName}", "What medicines do I have in ${applicationName}", "Medication list in ${applicationName}"]}}
		mapping, jobs = subject.prepare(catalogs)
		entries = [entry for entry in next(job for job in jobs if job["locale"] == "de")["entries"] if mapping["entries"][entry["key"]]["key"] == key and mapping["entries"][entry["key"]]["catalog"] == "AppShortcuts.xcstrings"]
		second = next(entry for entry in entries if mapping["entries"][entry["key"]]["path"][-1] == 1)
		self.assertEqual(second["english_variants"], ["Display my medications in ${applicationName}"])
		self.assertNotIn(key, second["english_variants"])
		self.assertNotIn("What medicines do I have in ${applicationName}", second["english_variants"])

	def test_malformed_shortcut_arrays_and_unsafe_list_paths_fail_without_mutation(self):
		for values in [None, {}, "phrase", [], [""], ["phrase", 7]]:
			catalogs = self.shortcuts_fixture()
			key = next(iter(catalogs["AppShortcuts.xcstrings"]["strings"]))
			catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["en"]["stringSet"]["values"] = values
			with self.subTest(values=values), self.assertRaisesRegex(ValueError, "stringSet"):
				subject.prepare(catalogs)
		catalogs = self.shortcuts_fixture()
		key = next(iter(catalogs["AppShortcuts.xcstrings"]["strings"]))
		catalogs["AppShortcuts.xcstrings"]["strings"][key]["localizations"]["de"] = {"stringSet": {"values": "invalid existing array"}}
		with self.assertRaisesRegex(ValueError, "stringSet"):
			subject.prepare(catalogs)
		node = {"stringSet": {"state": "new", "values": ["first", "second"]}}
		original = copy.deepcopy(node)
		for part in [-1, 2, True, "0", 0.0]:
			path = ["stringSet", "values", part]
			self.assertEqual(subject.at(node, path, "missing"), "missing")
			with self.assertRaises(ValueError):
				subject.put(node, path, "changed")
			self.assertEqual(node, original)
		with self.assertRaises(ValueError):
			subject.put(node, ["new", "values", 0], "changed")
		self.assertEqual(node, original)
		subject.put(node, ["stringSet", "values", 1], "changed")
		self.assertEqual(node["stringSet"]["values"], ["first", "changed"])

	def test_plural_category_review_allows_romanian_few_other_without_waiving_one(self):
		catalogs = self.fixture()
		catalogs["Localizable.xcstrings"]["strings"]["%lld active"] = {"localizations": {"ro": unit("%lld active")}}
		reviews = {"ro": {"Localizable.xcstrings": {"%lld active": {"%lld active": {"few": "Reviewed Romanian few adjective active", "other": "Reviewed Romanian other adjective active"}}}}}
		mapping, jobs = subject.prepare(catalogs, reviews)
		job = next(job for job in jobs if job["locale"] == "ro")
		entries = {entry["plural_form"]: entry for entry in job["entries"] if mapping["entries"][entry["key"]]["key"] == "%lld active"}
		self.assertEqual(set(entries), {"one", "few", "other"})
		self.assertTrue(all(entry["source"] == "%lld active" for entry in entries.values()))
		self.assertNotIn("allow_english", entries["one"])
		with self.assertRaisesRegex(ValueError, "untranslated English"):
			translation.validate_value(entries["one"], "%lld active", "ro")
		translation.validate_value(entries["one"], "%lld activ", "ro")
		for form in ["few", "other"]:
			translation.validate_value(entries[form], "%lld active", "ro")
		self.assertIsNone(subject.review_reason(reviews, "ro", "Localizable.xcstrings", "%lld active", "%lld active changed", True, "few"))
		self.assertIsNone(subject.review_reason(reviews, "ro", "Localizable.xcstrings", "%lld active", "%lld active", True, "one"))

	def test_plural_category_reviews_reject_malformed_scopes_and_nonplural_use(self):
		for scope in [{}, {"many": "Not a Romanian category"}, {"zero": "Not a Romanian category"}, {1: "Wrong category type"}, {"few": ""}, {"other": "   "}, {"few": 12}, {"few": {"nested": "invalid"}}]:
			reviews = {"ro": {"Localizable.xcstrings": {"%lld active": {"%lld active": scope}}}}
			with self.subTest(scope=scope), self.assertRaisesRegex(ValueError, "plural-category review"):
				subject.review_reason(reviews, "ro", "Localizable.xcstrings", "%lld active", "%lld active", True, "one")
		reviews = {"ro": {"Localizable.xcstrings": {"Active": {"Active": {"other": "Wrong scope"}}}}}
		with self.assertRaisesRegex(ValueError, "native plural leaf"):
			subject.review_reason(reviews, "ro", "Localizable.xcstrings", "Active", "Active", False)

	def test_narrowed_plural_category_review_revalidates_staging_and_old_leaf_caches(self):
		catalogs = self.fixture()
		catalogs["Localizable.xcstrings"]["strings"]["%lld active"] = {"localizations": {"ro": unit("%lld active")}}
		broad = {"ro": {"Localizable.xcstrings": {"%lld active": {"%lld active": "Old source-specific review"}}}}
		old_mapping, old_jobs = subject.prepare(catalogs, broad)
		old_job = next(job for job in old_jobs if job["locale"] == "ro")
		old_entries = [entry for entry in old_job["entries"] if old_mapping["entries"][entry["key"]]["key"] == "%lld active"]
		narrow = {"ro": {"Localizable.xcstrings": {"%lld active": {"%lld active": {"few": "Correct few", "other": "Correct other"}}}}}
		mapping, jobs = subject.prepare(catalogs, narrow)
		job = next(job for job in jobs if job["locale"] == "ro")
		entries = {entry["plural_form"]: entry for entry in job["entries"] if mapping["entries"][entry["key"]]["key"] == "%lld active"}
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory)
			translation.cache_valid_leaves({"translations": [{"key": entry["key"], "value": "%lld active"} for entry in old_entries]}, old_entries, "ro", cache, "broad-review")
			self.assertIsNone(translation.cached_leaf(cache, "ro", entries["one"]))
			for form in ["few", "other"]:
				self.assertEqual(translation.cached_leaf(cache, "ro", entries[form]), "%lld active")
			unused, pending = translation.pending_entries({"locale": "ro", "entries": list(entries.values())}, cache)
			self.assertEqual([entry["plural_form"] for entry in pending], ["one"])
		staged = self.staging(jobs)["ro"]
		staged["translations"][entries["one"]["key"]] = "%lld active"
		with self.assertRaisesRegex(ValueError, "untranslated English"):
			translation.validate_staged(staged, job)
		staged["translations"][entries["one"]["key"]] = "%lld activ"
		translation.validate_staged(staged, job)


if __name__ == "__main__":
	unittest.main()

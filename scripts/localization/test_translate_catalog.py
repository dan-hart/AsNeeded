from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import translate_catalog as subject


class TranslationValidationTests(unittest.TestCase):
	def test_rejects_english_copy_except_reviewed_identities(self):
		entry = {"key": "save", "source": "Save"}
		with self.assertRaisesRegex(ValueError, "English"):
			subject.validate_value(entry, "Save", "es")
		subject.validate_value({**entry, "allow_english": "Reviewed proper noun in this context"}, "Save", "es")
		subject.validate_value(entry, "Save", "en-GB")

	def test_placeholder_types_counts_and_explicit_reordering(self):
		entry = {"key": "dose", "source": "%@ has %lld doses (%.1f%%)"}
		subject.validate_value(entry, "%2$lld dosis para %1$@ (%3$.1f%%)", "es")
		for value in ["%@ tiene %d dosis (%.1f%%)", "%@ tiene dosis (%.1f%%)", "%lld %@ (%.1f%%)"]:
			with self.assertRaisesRegex(ValueError, "placeholder"):
				subject.validate_value(entry, value, "es")

	def test_schema_rejects_missing_duplicate_extra_and_nonstring(self):
		entries = [{"key": "save", "source": "Save"}]
		for items in [[], [{"key": "save", "value": "Guardar"}] * 2,
			[{"key": "other", "value": "Guardar"}], [{"key": "save", "value": 12}]]:
			with self.assertRaises(ValueError):
				subject.validate_response({"translations": items}, entries, "es")

	def test_plural_form_counts_are_locale_specific(self):
		entries = [{"key": f"doses::{form}", "source": "%lld doses", "plural_group": "doses", "plural_form": form}
			for form in ["one", "other"]]
		with self.assertRaisesRegex(ValueError, "plural forms"):
			subject.validate_job({"locale": "ar", "entries": entries})
		subject.validate_job({"locale": "en", "entries": entries})
		for form in ["zero", "two", "few", "many"]:
			entries.append({"key": f"doses::{form}", "source": "%lld doses", "plural_group": "doses", "plural_form": form})
		subject.validate_job({"locale": "ar", "entries": entries})

	def test_nested_icu_preserves_arguments_and_selectors(self):
		entry = {"key": "count", "source": "{count, plural, one {Dose} other {{name}: # doses}}"}
		subject.validate_value(entry, "{count, plural, one {Dosis} other {{name}: # dosis}}", "es")
		with self.assertRaisesRegex(ValueError, "ICU"):
			subject.validate_value(entry, "{count, plural, one {Dosis} other {{nombre}: # dosis}}", "es")

	def test_resume_reads_valid_cache_without_starting_cli(self):
		entries = [{"key": "save", "source": "Save"}]
		request = {"locale": "es", "entries": entries, "prompt_version": 1}
		digest = subject.hashlib.sha256(json.dumps(request, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory)
			(cache / f"{digest}.json").write_text(json.dumps({"translations": [{"key": "save", "value": "Guardar"}]}))
			with patch.object(subject.subprocess, "run", side_effect=AssertionError("CLI must not run")):
				result = subject.run({"locale": "es", "entries": entries}, cache)
			self.assertEqual(result["translations"]["save"], "Guardar")

	def test_preserves_valid_existing_and_retranslates_english(self):
		job = {"locale": "es", "entries": [{"key": "save", "source": "Save", "existing": "Guardar"},
			{"key": "cancel", "source": "Cancel", "existing": "Cancel"}]}
		with tempfile.TemporaryDirectory() as directory, patch.object(subject, "translate_batch", return_value={"translations": [{"key": "cancel", "value": "Cancelar"}]}) as translate:
			result = subject.run(job, Path(directory))
			self.assertEqual(result["translations"], {"save": "Guardar", "cancel": "Cancelar"})
			self.assertEqual([entry["key"] for entry in translate.call_args.args[1]], ["cancel"])


	def test_staging_rejects_changed_source_and_plural_metadata(self):
		job = {"locale": "es", "entries": [{"key": "save", "source": "Save", "existing": "Guardar"}]}
		with tempfile.TemporaryDirectory() as directory:
			staged = subject.run(job, Path(directory))
			subject.validate_staged(staged, job)
			with self.assertRaisesRegex(ValueError, "fingerprint"):
				subject.validate_staged(staged, {**job, "entries": [{"key": "save", "source": "Save now"}]})
			with self.assertRaisesRegex(ValueError, "plural metadata"):
				subject.validate_staged({**staged, "plural_entries": [{"key": "fake"}]}, job)

	def test_markup_urls_and_newlines_preserved(self):
		entry = {"key": "help", "source": "<b>Help</b>\nhttps://example.com/help"}
		subject.validate_value(entry, "<b>Ayuda</b>\nhttps://example.com/help", "es")
		for translated in ["<i>Ayuda</i>\nhttps://example.com/help", "<b>Ayuda</b> https://example.com/help", "<b>Ayuda</b>\nhttps://example.com/otro"]:
			with self.assertRaises(ValueError):
				subject.validate_value(entry, translated, "es")

	def test_cannot_overwrite_source_catalog(self):
		with tempfile.TemporaryDirectory() as directory:
			path = Path(directory) / "Localizable.xcstrings"
			path.write_text("original")
			with self.assertRaisesRegex(ValueError, "catalogs"):
				subject.atomic_json(path, {"translations": {}})
			self.assertEqual(path.read_text(), "original")

	def test_product_brand_and_public_email_are_preserved(self):
		entry = {"key": "contact", "source": "Contact AsNeeded: asneeded@codedbydan.com"}
		subject.validate_value(entry, "Contactar AsNeeded: asneeded@codedbydan.com", "es")
		for value in ["Contactar SegúnNecesidad: asneeded@codedbydan.com", "Contactar AsNeeded: changed@example.com"]:
			with self.assertRaises(ValueError):
				subject.validate_value(entry, value, "es")

	def test_public_email_allows_adjacent_japanese_arabic_hebrew_and_punctuation(self):
		entry = {"key": "contact", "source": "Copy asneeded@codedbydan.com to send email manually"}
		for locale, value in [
			("ja", "asneeded@codedbydan.comをコピーして手動でメールを送信"),
			("ja", "連絡先asneeded@codedbydan.comをコピー"),
			("ar", "انسخasneeded@codedbydan.comلإرسالالبريد"),
			("he", "העתקasneeded@codedbydan.comכדילשלוח"),
			("es", "Copiar (asneeded@codedbydan.com)."),
			("es", "Copiar: asneeded@codedbydan.com, para enviar un correo."),
		]:
			with self.subTest(locale=locale, value=value):
				subject.validate_value(entry, value, locale)
		punctuated = {**entry, "source": "Contact: (asneeded@codedbydan.com)."}
		subject.validate_value(punctuated, "連絡先asneeded@codedbydan.comをコピー", "ja")

	def test_public_email_rejects_changed_address_domain_suffix_drops_and_duplicates(self):
		entry = {"key": "contact", "source": "Copy asneeded@codedbydan.com to send email manually"}
		for address in ["changed@codedbydan.com", "asneeded@changed.com", "asneeded@codedbydan.com.evil", "asneeded@codedbydan.comx", "asneeded@codedbydan.com-evil", "asneeded@codedbydan.com_suffix", "asneeded@codedbydan.com+suffix", "asneeded@codedbydan.com@evil", ""]:
			with self.subTest(address=address), self.assertRaisesRegex(ValueError, "public email"):
				subject.validate_value(entry, address + "をコピー", "ja")
		with self.assertRaisesRegex(ValueError, "public email"):
			subject.validate_value(entry, "asneeded@codedbydan.com、asneeded@codedbydan.comをコピー", "ja")

	def test_native_substitution_identifier_is_not_translatable(self):
		entry = {"key": "native", "source": "%#@count@", "allow_english": "Native catalog substitution wrapper"}
		subject.validate_value(entry, "%#@count@", "es")
		with self.assertRaisesRegex(ValueError, "substitution"):
			subject.validate_value(entry, "%#@cuenta@", "es")

	def test_native_argument_marker_cannot_be_truncated_renamed_or_dropped(self):
		entry = {"key": "count", "source": "%arg medication records"}
		subject.validate_value(entry, "%arg dossiers de médicaments", "fr")
		for value in ["%a dossiers de médicaments", "%args dossiers de médicaments", "%argX dossiers de médicaments", "dossiers de médicaments", "%%arg dossiers de médicaments"]:
			with self.subTest(value=value), self.assertRaisesRegex(ValueError, "placeholder"):
				subject.validate_value(entry, value, "fr")
		self.assertNotEqual(subject.placeholders("%arg"), subject.placeholders("%a"))

	def test_positional_native_substitutions_preserve_selector_and_argument_number(self):
		entry = {"key": "counts", "source": "Found %1$#@medicationRecords@ and %2$#@eventRecords@."}
		subject.validate_value(entry, "Trouvé %1$#@medicationRecords@ et %2$#@eventRecords@.", "fr")
		for value in ["Trouvé %1$#@medications@ et %2$#@eventRecords@.", "Trouvé %2$#@medicationRecords@ et %1$#@eventRecords@.", "Trouvé %#@medicationRecords@ et %2$#@eventRecords@."]:
			with self.subTest(value=value), self.assertRaisesRegex(ValueError, "native substitution"):
				subject.validate_value(entry, value, "fr")

	def test_siri_tokens_keep_dollar_spelling_counts_and_allow_reordering(self):
		entry = {"key": "shortcut", "source": "Log ${medication} in ${applicationName}"}
		subject.validate_value(entry, "Dans ${applicationName}, enregistrer ${medication}", "fr")
		for value in ["Enregistrer {medication} dans ${applicationName}", "Enregistrer ${medication} dans {applicationName}", "Enregistrer ${medicine} dans ${applicationName}", "Enregistrer ${medication} dans ${appName}", "Enregistrer ${medication}", "Enregistrer ${medication} ${medication} dans ${applicationName}", "Enregistrer ${medication} dans $${applicationName}"]:
			with self.subTest(value=value), self.assertRaisesRegex(ValueError, "native Siri token"):
				subject.validate_value(entry, value, "fr")

	def test_failed_batch_caches_good_leaves_then_only_retries_invalid_leaf(self):
		job = {"locale": "es", "entries": [{"key": "save", "source": "Save"}, {"key": "color", "source": "Color"}]}
		calls = []
		def provider(command, **unused):
			request = json.loads(command[-1].split("\n", 1)[1])
			calls.append([entry["key"] for entry in request["entries"]])
			output = Path(command[command.index("--output-last-message") + 1])
			output.write_text(json.dumps({"translations": [{"key": entry["key"], "value": "Guardar" if entry["key"] == "save" else "Color"} for entry in request["entries"]]}))
			return subject.subprocess.CompletedProcess(command, 0, "", "")
		with tempfile.TemporaryDirectory() as directory, patch.object(subject.subprocess, "run", side_effect=provider):
			cache = Path(directory)
			with self.assertRaisesRegex(ValueError, "English"):
				subject.run(job, cache)
			self.assertEqual(subject.cached_leaf(cache, "es", job["entries"][0]), "Guardar")
			self.assertIsNone(subject.cached_leaf(cache, "es", job["entries"][1]))
			job["entries"][1]["allow_english"] = "Reviewed Spanish cognate"
			result = subject.run(job, cache)
			self.assertEqual(calls, [["save", "color"], ["color"]])
			self.assertEqual(result["translations"], {"save": "Guardar", "color": "Color"})
			with patch.object(subject.subprocess, "run", side_effect=AssertionError("all leaves must resume")):
				subject.run(job, cache)

	def test_invalid_envelope_never_caches_even_individually_good_values(self):
		entries = [{"key": "save", "source": "Save"}, {"key": "cancel", "source": "Cancel"}]
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory)
			with self.assertRaisesRegex(ValueError, "missing"):
				subject.cache_valid_leaves({"translations": [{"key": "save", "value": "Guardar"}]}, entries, "es", cache, "batch")
			self.assertIsNone(subject.cached_leaf(cache, "es", entries[0]))

	def test_backfill_requires_original_batch_digest_and_retains_only_valid_leaves(self):
		job = {"locale": "es", "entries": [{"key": "save", "source": "Save"}, {"key": "color", "source": "Color"}]}
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory)
			unused, digest = subject.batch_request("es", job["entries"])
			(cache / f"{digest}.rejected.json").write_text(json.dumps({"translations": [{"key": "save", "value": "Guardar"}, {"key": "color", "value": "Color"}]}))
			report = subject.backfill_rejected(job, cache)
			self.assertEqual(report["recovered"], 1)
			self.assertEqual(len(report["invalid"]), 1)
			self.assertTrue((cache / f"{digest}.request.json").exists())
			self.assertIsNone(subject.cached_leaf(cache, "de", job["entries"][0]))
			self.assertEqual(subject.backfill_rejected({**job, "locale": "de"}, cache)["recovered"], 0)

	def test_rejects_actual_english_variants_with_case_and_whitespace_normalization(self):
		entry = {"key": "colour", "source": "Choose your favourite colour.", "english_variants": ["Choose your favorite color."]}
		for value in ["Choose your favorite color.", "  CHOOSE   YOUR FAVOURITE COLOUR.  "]:
			with self.assertRaisesRegex(ValueError, "untranslated English"):
				subject.validate_value(entry, value, "fr")
		subject.validate_value(entry, "Choisissez votre couleur préférée.", "fr")
		subject.validate_value(entry, "Choose your favorite color.", "en-AU")
		subject.validate_value({"key": "colour", "source": "Colour", "english_variants": ["Color"], "allow_english": "Reviewed Spanish cognate Color"}, "Color", "es")

	def test_directional_controls_cannot_hide_english_source_or_regional_variant(self):
		entry = {"key": "colour", "source": "Choose your favourite colour.", "english_variants": ["Choose your favorite color."]}
		for value in ["\u200fChoose your favourite colour.", "\u2068Choose your favourite colour.\u2069", "Choose\u200e your favorite color.", "\u200f\u2068CHOOSE   YOUR FAVORITE COLOR.\u2069", "Choose your favourite co\u200dlour."]:
			with self.subTest(value=value), self.assertRaisesRegex(ValueError, "untranslated English"):
				subject.validate_value(entry, value, "ar")
		subject.validate_value(entry, "\u200f\u2068اختر لونك المفضل.\u2069", "ar")

	def test_reviewed_rtl_format_wrapper_keeps_its_controls_in_cache_and_staging(self):
		entry = {"key": "field", "source": "%@: %@", "allow_english": "Reviewed format-only label/value template with intentional RTL paragraph mark"}
		value = "\u200f%1$@: %2$@"
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory) / "cache"
			self.assertEqual(subject.cache_valid_leaves({"translations": [{"key": "field", "value": value}]}, [entry], "ar", cache, "rtl-proof"), [])
			self.assertEqual(subject.cached_leaf(cache, "ar", entry), value)
			with patch.object(subject.subprocess, "run", side_effect=AssertionError("validated cache must not call provider")):
				staged = subject.run({"locale": "ar", "entries": [entry]}, cache)
			output = Path(directory) / "staging.json"
			subject.atomic_json(output, staged)
			self.assertEqual(json.loads(output.read_text())["translations"]["field"], value)
			self.assertTrue(staged["translations"]["field"].startswith("\u200f"))

	def test_malformed_english_variants_fail_before_translation_or_cache_reuse(self):
		for variants in ["Color", [], [""], ["   "], [None], [1], {"en-US": "Color"}]:
			entry = {"key": "colour", "source": "Colour", "english_variants": variants}
			with self.assertRaisesRegex(ValueError, "english_variants"):
				subject.validate_job({"locale": "fr", "entries": [entry]})
			with self.assertRaisesRegex(ValueError, "english_variants"):
				subject.validate_value(entry, "Couleur", "fr")

	def test_new_english_variants_revalidate_leaf_cache_without_discarding_other_valid_leaves(self):
		entries = [{"key": "colour", "source": "Colour"}, {"key": "save", "source": "Save"}]
		with tempfile.TemporaryDirectory() as directory:
			cache = Path(directory)
			subject.cache_valid_leaves({"translations": [{"key": "colour", "value": "Color"}, {"key": "save", "value": "Enregistrer"}]}, entries, "fr", cache, "original")
			entries[0]["english_variants"] = ["Color"]
			self.assertIsNone(subject.cached_leaf(cache, "fr", entries[0]))
			self.assertEqual(subject.cached_leaf(cache, "fr", entries[1]), "Enregistrer")
			with patch.object(subject, "translate_batch", return_value={"translations": [{"key": "colour", "value": "Couleur"}]}) as translate:
				result = subject.run({"locale": "fr", "entries": entries}, cache, workers=1)
			self.assertEqual(translate.call_args.args[1], [entries[0]])
			self.assertEqual(result["translations"], {"colour": "Couleur", "save": "Enregistrer"})


class TranslationQueueTests(unittest.TestCase):
	def queue(self, root, locales):
		for locale in locales:
			(root / f"{locale}.json").write_text(json.dumps({"locale": locale, "entries": [{"key": "save", "source": "Save"}]}))
		path = root / "queue.json"
		path.write_text(json.dumps({"required_locales": locales, "jobs": [f"{locale}.json" for locale in locales]}))
		return ["translate_catalog.py", str(path), "--queue", "--output", str(root / "staged"), "--cache", str(root / "cache"), "--workers", "1"]

	def test_keep_going_finishes_later_locale_and_reports_all_failures_without_staging_them(self):
		calls = []
		def translate(locale, entries, cache, timeout):
			calls.append(locale)
			if locale == "es":
				# A nominal provider success still must pass the real final validation gate.
				return {"translations": [{"key": "save", "value": "Save"}]}
			if locale == "fr":
				raise RuntimeError("translation CLI timed out\n" + "detail " * 100)
			return {"translations": [{"key": "save", "value": "Speichern"}]}
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			argv = self.queue(root, ["es", "de", "fr"]) + ["--keep-going"]
			stdout, stderr = io.StringIO(), io.StringIO()
			with patch("sys.argv", argv), patch.object(subject, "translate_batch", side_effect=translate), redirect_stdout(stdout), redirect_stderr(stderr):
				with self.assertRaises(SystemExit) as stopped:
					subject.main()
			self.assertEqual(stopped.exception.code, 1)
			self.assertEqual(calls, ["es", "de", "fr"])
			self.assertFalse((root / "staged/es.json").exists())
			self.assertFalse((root / "staged/fr.json").exists())
			staged = json.loads((root / "staged/de.json").read_text())
			subject.validate_staged(staged, json.loads((root / "de.json").read_text()))
			self.assertIn("Validated 1 translations for de", stdout.getvalue())
			self.assertNotIn("Validated 1 translations for es", stdout.getvalue())
			self.assertIn("Queue failed for 2 locale(s)", stderr.getvalue())
			self.assertIn("es: save: untranslated English", stderr.getvalue())
			self.assertIn("fr: translation CLI timed out", stderr.getvalue())
			self.assertLess(len(stderr.getvalue()), 400)

	def test_default_queue_still_stops_on_first_failure(self):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			argv = self.queue(root, ["es", "de"])
			with patch("sys.argv", argv), patch.object(subject, "translate_batch", side_effect=RuntimeError("failed")) as translate, redirect_stdout(io.StringIO()):
				with self.assertRaisesRegex(RuntimeError, "failed"):
					subject.main()
			self.assertEqual(translate.call_count, 1)
			self.assertFalse((root / "staged/de.json").exists())

	def test_keep_going_validate_only_checks_later_staging_without_starting_provider(self):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			argv = self.queue(root, ["es", "de"]) + ["--keep-going", "--validate-only"]
			job = json.loads((root / "de.json").read_text())
			job["entries"][0]["existing"] = "Speichern"
			(root / "de.json").write_text(json.dumps(job))
			staged = subject.run(job, root / "cache")
			subject.atomic_json(root / "staged/de.json", staged)
			stdout = io.StringIO()
			with patch("sys.argv", argv), patch.object(subject.subprocess, "run", side_effect=AssertionError("provider must not run")), redirect_stdout(stdout), redirect_stderr(io.StringIO()):
				with self.assertRaises(SystemExit) as stopped:
					subject.main()
			self.assertEqual(stopped.exception.code, 1)
			self.assertIn("Validated 1 translations for de", stdout.getvalue())
			self.assertEqual(json.loads((root / "staged/de.json").read_text()), staged)

	def test_keep_going_requires_queue(self):
		with patch("sys.argv", ["translate_catalog.py", "job.json", "--output", "staged.json", "--cache", "cache", "--keep-going"]), redirect_stderr(io.StringIO()) as stderr:
			with self.assertRaises(SystemExit) as stopped:
				subject.main()
		self.assertEqual(stopped.exception.code, 2)
		self.assertIn("--keep-going requires --queue", stderr.getvalue())


if __name__ == "__main__":
	unittest.main()

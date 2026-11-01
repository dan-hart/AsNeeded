#!/usr/bin/env python3
"""Prepare public catalog jobs and merge validated staging into NEW candidate files."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

import translate_catalog as translation

PRIORITY = ["es", "de", "fr", "ar", "he", "fa", "ja"]
UNITS = "milligram gram microgram unit tablet capsule chewable lozenge suppository milliliter liter teaspoon drop sachet puff nebule injection tablespoon pen inhaler vial patch application spray strip film dose ampule bowl joint dab".split()
SINGULAR = {word + "s": word for word in UNITS + ["day", "hour", "minute", "second", "week", "month", "year", "medication", "reminder", "event", "entry", "dose", "record", "log", "file", "item", "character", "backup"]}
SINGULAR.update({"entries": "entry", "suppositories": "suppository", "patches": "patch"})
# Deliberately narrow reviewed identity list. Cognates are locale-specific overrides.
IDENTITIES = {"AsNeeded": "English product brand", "As Needed": "English product brand",
	"HealthKit": "Apple framework proper noun", "Apple Health": "Apple service proper noun",
	"iCloud": "Apple service proper noun", "GitHub": "Service proper noun",
	"NIH": "US public-health agency acronym", "NLM": "US medical library acronym",
	"NIH/NLM": "US public-health agency acronyms", "NIH/NLM RxNorm": "Agency acronyms and database proper noun",
	"RxNorm": "Medical terminology database proper noun", "MedlinePlus (NIH)": "Public-health service proper noun",
	"Atkinson Hyperlegible": "Font family proper noun", "OpenDyslexic": "Font family proper noun",
	"mg": "International mass abbreviation", "g": "International mass abbreviation",
	"mcg": "International mass abbreviation", "mL": "International volume abbreviation", "L": "International volume abbreviation"}
IDENTITIES.update({name: "Reviewed exact public proper noun or technical identifier" for name in [
	"CDC", "FDA", "WHO", "NIH", "Christine Wang", "Kevin Wang", "MedlinePlus", "Mayo Clinic",
	"Apple", "App Store", "TestFlight", "RevenueCat", "SwiftUI", "ANModelKit", "Boutique",
	"DHLoggingKit", "DHFlatUIColors", "SFSafeSymbols", "SwiftRxNorm", "GPL-3.0", "JSON", "API", "UUID"]})


# Explicit shipping messages only; each native substitution owns its count axis.
MULTICOUNT = {
	"%@\n%lld medications, %lld events": (
		"%1$@\n%2$#@medications@, %3$#@events@",
		[("medications", 2, "%arg medication", "%arg medications"), ("events", 3, "%arg event", "%arg events")]),
	"Data imported successfully\n%lld medications, %lld events": (
		"Data imported successfully\n%1$#@medications@, %2$#@events@",
		[("medications", 1, "%arg medication", "%arg medications"), ("events", 2, "%arg event", "%arg events")]),
	"Found %lld medication records and %lld event records in historical sources. Some may already be in current storage or another source.": (
		"Found %1$#@medicationRecords@ and %2$#@eventRecords@ in historical sources. Some may already be in current storage or another source.",
		[("medicationRecords", 1, "%arg medication record", "%arg medication records"), ("eventRecords", 2, "%arg event record", "%arg event records")]),
	"Partial import: %lld items imported, %lld failed": (
		"Partial import: %1$#@importedItems@, %2$#@failedItems@",
		[("importedItems", 1, "%arg item imported", "%arg items imported"), ("failedItems", 2, "%arg item failed", "%arg items failed")]),
}


def multicount_template(key):
	wrapper, counts = MULTICOUNT[key]
	return {"stringUnit": {"state": "translated", "value": wrapper}, "substitutions": {
		name: {"argNum": argument, "formatSpecifier": "lld", "variations": {"plural": {
			"one": {"stringUnit": {"state": "translated", "value": one}},
			"other": {"stringUnit": {"state": "translated", "value": other}}}}}
		for name, argument, one, other in counts}}


def review_reason(reviews, locale, filename, key, source, plural, plural_form=None):
	review = reviews.get(locale, {}).get(filename, {}).get(key)
	if isinstance(review, dict):
		# An exact source may additionally scope approval to native plural categories.
		reason = review.get(source)
		if isinstance(reason, dict):
			if not plural or plural_form is None:
				raise ValueError("plural-category review requires a native plural leaf")
			forms = translation.plural_forms(locale)
			if not reason or any(not isinstance(form, str) or form not in forms for form in reason):
				raise ValueError("plural-category review must use current locale plural forms")
			if any(not isinstance(value, str) or not value.strip() for value in reason.values()):
				raise ValueError("plural-category review requires a nonempty written reason per selected form")
			return reason.get(plural_form)
		if reason is not None and (not isinstance(reason, str) or not reason.strip()):
			raise ValueError("source-specific review requires a nonempty written reason")
		return reason
	if review is not None:
		if not isinstance(review, str) or not review.strip():
			raise ValueError("review requires a nonempty written reason")
		if plural and not identity_reason(source):
			raise ValueError(f"{locale}:{filename}:{key}: plural review must select an exact source variant")
	return review



def fingerprint(value):
	return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def leaves(node, path=()):
	if isinstance(node, dict):
		if "stringUnit" in node:
			yield path + ("stringUnit", "value"), node["stringUnit"]["value"]
		if "stringSet" in node:
			string_set = node["stringSet"]
			if not isinstance(string_set, dict) or not isinstance(string_set.get("values"), list) or not string_set["values"] or any(not isinstance(value, str) or not value.strip() for value in string_set["values"]):
				raise ValueError("native stringSet values must be a nonempty array of nonempty strings")
			for index, value in enumerate(string_set["values"]):
				yield path + ("stringSet", "values", index), value
		for key, value in node.items():
			if key not in {"stringUnit", "stringSet"} and isinstance(value, dict):
				yield from leaves(value, path + (key,))


def child(node, part):
	if isinstance(node, dict) and isinstance(part, str):
		return node[part]
	if isinstance(node, list) and type(part) is int and 0 <= part < len(node):
		return node[part]
	raise ValueError("invalid native catalog path or array index")


def at(node, path, default=None):
	try:
		for part in path:
			node = child(node, part)
		return node
	except (KeyError, ValueError):
		return default


def put(node, path, value):
	if not path:
		raise ValueError("native catalog write requires a nonempty path")
	for index, part in enumerate(path[:-1]):
		if isinstance(node, dict) and isinstance(part, str) and part not in node:
			# New dictionaries are allowed; arrays must already have their native shape.
			if any(not isinstance(key, str) for key in path[index:]):
				raise ValueError("native catalog arrays cannot be created or extended by an indexed write")
			for key in path[index:-1]:
				node = node.setdefault(key, {})
			node[path[-1]] = value
			return
		try:
			node = child(node, part)
		except KeyError:
			raise ValueError("missing native catalog path") from None
	final = path[-1]
	if isinstance(node, dict) and isinstance(final, str):
		node[final] = value
	elif isinstance(node, list) and type(final) is int and 0 <= final < len(node):
		node[final] = value
	else:
		raise ValueError("invalid native catalog write path or array index")


def string_set_leaf(path):
	return len(path) >= 3 and list(path[-3:-1]) == ["stringSet", "values"] and type(path[-1]) is int


def leaf_container(path):
	return path[:-2] if string_set_leaf(path) else path[:-1]


def singular(source):
	# Change only the noun governed by the count, never unrelated plural nouns.
	matches = list(translation.PERCENT.finditer(source.replace("%%", "")))
	numeric = [match for match in matches if match[2][-1] in "diugf"]
	if len(numeric) != 1:
		return source
	count = numeric[0]
	noun = re.search(r"\b(" + "|".join(sorted(SINGULAR, key=len, reverse=True)) + r")\b", source[count.end():], re.I)
	if noun and noun.start() < 40:
		start, end = count.end() + noun.start(), count.end() + noun.end()
		replacement = SINGULAR[noun[0].lower()]
		if noun[0].istitle():
			replacement = replacement.title()
		elif noun[0].isupper():
			replacement = replacement.upper()
		source = source[:start] + replacement + source[end:]
		source = source.replace("There are ", "There is ")
	return source


def count_phrase(source):
	numeric = [match for match in translation.PERCENT.finditer(source.replace("%%", "")) if match[2][-1] in "diugf"]
	if len(numeric) != 1:
		return False
	count = numeric[0]
	after = source[count.end():]
	if re.match(r"d\b", after):
		return True
	if source in {"%lld active", "Show All (%lld)"}:
		return True
	nouns = set(SINGULAR) | set(SINGULAR.values())
	# A count must govern a following noun. An index before ': No doses' and
	# numeric percentage/progress strings must never become medication plurals.
	phrase = re.match(r"\s+([A-Za-z ]+)", after)
	return bool(phrase and any(re.search(r"\b" + re.escape(noun) + r"\b", phrase[1], re.I) for noun in nouns))


def semantic_identifier(value):
	if identity_reason(value):
		return False
	return bool(
		re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:[._:][A-Za-z0-9_]+)+", value)
		or re.fullmatch(r"[a-z]+(?:[A-Z][A-Za-z0-9]*)+", value)
		or re.fullmatch(r"[A-Z][a-z]+(?:[A-Z][A-Za-z0-9]*)+", value)
		or re.fullmatch(r"(?:NS|CF|UI|HK)[A-Z][A-Za-z0-9]*", value)
		or re.fullmatch(r"[A-Z]{2,}[A-Z][a-z][A-Za-z0-9]*", value)
		or re.fullmatch(r"[A-Za-z]+[0-9]+[A-Za-z0-9]*", value)
	)


def english_source_node(key, entry):
	localizations = entry.get("localizations", {})
	for locale in ["en", "en-US", "en-GB", "en-AU"]:
		node = localizations.get(locale)
		if node is None or not list(leaves(node)):
			continue
		if any(value == key and semantic_identifier(value) for unused, value in leaves(node)):
			continue
		return copy.deepcopy(node)
	if semantic_identifier(key):
		raise ValueError(f"{key}: semantic catalog identifier has no English display source; resolve manually")
	return {"stringUnit": {"state": "translated", "value": key}}


def source_template(key, entry):
	node = english_source_node(key, entry)
	if key in MULTICOUNT and not node.get("substitutions"):
		return multicount_template(key)
	if "stringUnit" in node and count_phrase(node["stringUnit"]["value"]):
		value = node["stringUnit"]["value"].replace("(s)", "s")
		node = {"variations": {"plural": {
			"one": {"stringUnit": {"state": "translated", "value": singular(value)}},
			"other": {"stringUnit": {"state": "translated", "value": value}}}}}
	return node


def adapt_plurals(node, locale):
	node = copy.deepcopy(node)
	if not isinstance(node, dict):
		return node
	if "plural" in node and isinstance(node["plural"], dict):
		forms = node["plural"]
		fallback = forms.get("other")
		if fallback is None:
			raise ValueError("native plural tree is missing other")
		node["plural"] = {form: adapt_plurals(forms.get(form, fallback), locale) for form in sorted(translation.plural_forms(locale))}
	for key in list(node):
		if key != "plural" and isinstance(node[key], dict):
			node[key] = adapt_plurals(node[key], locale)
	return node


def identity_reason(source):
	if source in IDENTITIES:
		return IDENTITIES[source]
	if re.fullmatch(r"%#@[A-Za-z_][A-Za-z0-9_]*@", source):
		return "Native string-catalog substitution identifier is format-only"
	if re.fullmatch(r"[A-Za-z0-9.+_-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", source):
		return "Exact public contact email identifier must remain unchanged"
	if re.fullmatch(r"©\s*\d{4}(?:[–-]\d{4})?\s+Dan Hart", source):
		return "Public copyright year and publisher proper noun"
	if re.fullmatch(r"https?://\S+", source):
		return "Exact public URL must remain unchanged"
	remaining = source.replace("%%", "")
	remaining = translation.NATIVE_SUBSTITUTION.sub("", remaining)
	remaining = translation.NATIVE_ARGUMENT.sub("", remaining)
	remaining = translation.PERCENT.sub("", remaining)
	if remaining and not any(character.isalpha() for character in remaining):
		return "Format-only punctuation and numeric text has no translatable language"
	if not remaining:
		return "Format-only placeholders have no translatable language"
	return None


def reconcile(catalogs, extracted):
	for filename, strings in extracted.items():
		if filename not in catalogs:
			continue
		for key, record in strings.items():
			entry = catalogs[filename]["strings"].setdefault(key, {})
			if record.get("comment") and not entry.get("comment"):
				entry["comment"] = record["comment"]
			if record.get("source") is not None and record["source"] != key:
				entry.setdefault("localizations", {}).setdefault("en", {"stringUnit": {"state": "translated", "value": record["source"]}})
	return catalogs


def read_extracted(xliffs=(), stringsdata_roots=()):
	result = {}
	for filename in xliffs:
		root = ET.parse(filename).getroot()
		for file in root.findall(".//{*}file"):
			table = Path(file.get("original", "")).stem + ".xcstrings"
			for unit in file.findall(".//{*}trans-unit"):
				source = unit.find("{*}source")
				if source is not None and unit.get("id") is not None:
					result.setdefault(table, {})[unit.get("id")] = {"source": "".join(source.itertext())}
	for directory in stringsdata_roots:
		for path in Path(directory).rglob("*.stringsdata"):
			data = json.loads(path.read_text())
			for table, records in data.get("tables", {}).items():
				for record in records:
					result.setdefault(table + ".xcstrings", {})[record["key"]] = {"source": record.get("value", record["key"]), "comment": record.get("comment", "")}
	return result


def english_variants(key, item, path, source, locale):
	"""Actual English leaves at the same native path, with CLDR other fallback."""
	values = []
	for english_locale in ["en", "en-US", "en-GB", "en-AU"]:
		node = item.get("localizations", {}).get(english_locale)
		if node is None:
			continue
		value = at(adapt_plurals(node, locale), path)
		# A plain English count leaf may have become a generated plural template.
		if value is None and len(path) == 5 and path[:2] == ("variations", "plural") and path[3:] == ("stringUnit", "value"):
			value = at(node, ("stringUnit", "value"))
		if isinstance(value, str) and value.strip() and not semantic_identifier(value):
			values.append(value)
	if "substitutions" not in path and (not string_set_leaf(path) or path[-1] == 0) and key.strip() and not semantic_identifier(key):
		values.append(key)
	return list(dict.fromkeys(value for value in values if value != source))


def prepare(catalogs, reviews=None):
	reviews = reviews or {}
	catalogs = copy.deepcopy(catalogs)
	localizable = catalogs["Localizable.xcstrings"]
	locales = {locale for entry in localizable["strings"].values() for locale in entry.get("localizations", {})}
	locales.add(localizable.get("sourceLanguage", "en"))
	ordered = [locale for locale in PRIORITY if locale in locales] + sorted(locales - set(PRIORITY))
	mapping = {"catalogs": catalogs, "catalog_sha256": fingerprint(catalogs), "locales": ordered, "entries": {}, "templates": {}}
	jobs = []
	for locale in ordered:
		entries = []
		mapping["templates"][locale] = {}
		for filename, catalog in sorted(catalogs.items()):
			mapping["templates"][locale][filename] = {}
			for key, item in catalog["strings"].items():
				for native in item.get("localizations", {}).values():
					list(leaves(native))  # Reject malformed source/existing native arrays before staging.
				template = adapt_plurals(source_template(key, item), locale)
				mapping["templates"][locale][filename][key] = template
				for path, source in leaves(template):
					if source == "":
						continue
					identifier = "s" + fingerprint([filename, key, path])[:24]
					mapping["entries"][identifier] = {"catalog": filename, "key": key, "path": list(path)}
					entry = {"key": identifier, "source": source}
					variants = english_variants(key, item, path, source, locale)
					if variants:
						entry["english_variants"] = variants
					if "plural" in path:
						index = path.index("plural")
						entry.update(plural_group="p" + fingerprint([filename, key, path[:index]])[:24], plural_form=path[index + 1])
					if item.get("comment"):
						entry["comment"] = item["comment"]
					reason = review_reason(reviews, locale, filename, key, source, "plural" in path, entry.get("plural_form")) or identity_reason(source)
					if reason:
						entry["allow_english"] = reason
					if item.get("shouldTranslate") is False and not reason:
						raise ValueError(f"{filename}:{key}: untranslatable catalog key needs a reviewed identity reason")
					existing = at(item.get("localizations", {}).get(locale, {}), path)
					if identity_reason(source) and translation.NATIVE_SUBSTITUTION.search(source):
						try:
							translation.validate_value(entry, existing, locale)
						except ValueError:
							# A punctuation-only native wrapper needs no provider translation.
							existing = source
					if item.get("shouldTranslate") is False:
						existing = source
					# Source English variants are deterministic; regional English remains provider-reviewed if missing.
					if locale == "en":
						existing = source
					if existing is not None:
						entry["existing"] = existing
					entries.append(entry)
		job = {"locale": locale, "entries": entries}
		translation.validate_job(job)
		jobs.append(job)
	mapping["jobs_sha256"] = {job["locale"]: translation.job_digest(job) for job in jobs}
	return mapping, jobs


def merge(mapping, jobs, staged):
	if fingerprint(mapping["catalogs"]) != mapping["catalog_sha256"]:
		raise ValueError("source catalog snapshot fingerprint mismatch")
	if {job["locale"] for job in jobs} != set(mapping["locales"]) or len(jobs) != len(mapping["locales"]):
		raise ValueError("candidate merge requires every catalog locale exactly once")
	candidates = copy.deepcopy(mapping["catalogs"])
	for job in jobs:
		locale = job["locale"]
		if translation.job_digest(job) != mapping["jobs_sha256"][locale]:
			raise ValueError("job changed since prepare")
		translation.validate_job(job)
		translation.validate_staged(staged[locale], job)
		for filename, trees in mapping["templates"][locale].items():
			for key, tree in trees.items():
				tree = copy.deepcopy(tree)
				item = candidates[filename]["strings"][key]
				existing = item.get("localizations", {}).get(locale, {})
				# Preserve existing leaf metadata where its native path remains valid.
				containers = {leaf_container(path) for path, unused in leaves(tree)}
				for path in containers:
					old_unit = at(existing, path)
					if old_unit:
						metadata = copy.deepcopy(old_unit)
						if path[-1] == "stringSet":
							metadata["values"] = copy.deepcopy(at(tree, path)["values"])
						put(tree, path, metadata)
				item.setdefault("localizations", {})[locale] = copy.deepcopy(tree)
		for entry in job["entries"]:
			record = mapping["entries"][entry["key"]]
			node = candidates[record["catalog"]]["strings"][record["key"]]["localizations"][locale]
			path = record["path"]
			value = staged[locale]["translations"][entry["key"]]
			put(node, path, value)
			container = leaf_container(path)
			# Every staged leaf has passed validation, including unchanged source/existing text.
			put(node, container + ["state"], "translated")
	return candidates


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	sub = parser.add_subparsers(dest="command", required=True)
	prep = sub.add_parser("prepare")
	prep.add_argument("--catalog", type=Path, action="append", required=True)
	prep.add_argument("--xliff", type=Path, action="append", default=[])
	prep.add_argument("--stringsdata-root", type=Path, action="append", default=[])
	prep.add_argument("--reviews", type=Path)
	prep.add_argument("--output", type=Path, required=True)
	merger = sub.add_parser("merge")
	merger.add_argument("--jobs", type=Path, required=True)
	merger.add_argument("--staging", type=Path, required=True)
	merger.add_argument("--output", type=Path, required=True)
	args = parser.parse_args()
	if args.command == "prepare":
		if args.output.exists():
			raise ValueError("prepare output must be a new directory")
		catalogs = {path.name: json.loads(path.read_text()) for path in args.catalog}
		if len(catalogs) != len(args.catalog):
			raise ValueError("catalog filenames must be unique")
		reconcile(catalogs, read_extracted(args.xliff, args.stringsdata_root))
		mapping, jobs = prepare(catalogs, json.loads(args.reviews.read_text()) if args.reviews else None)
		mapping["source_files"] = {path.name: {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in args.catalog}
		translation.atomic_json(args.output / "mapping.json", mapping)
		for job in jobs:
			translation.atomic_json(args.output / f"{job['locale']}.json", job)
		translation.atomic_json(args.output / "queue.json", {"required_locales": mapping["locales"], "jobs": [f"{job['locale']}.json" for job in jobs]})
		print(f"Prepared {len(jobs)} locale jobs; {len(mapping['entries'])} distinct catalog leaves")
	else:
		if args.output.exists():
			raise ValueError("candidate output must be a new directory; source catalogs are never overwritten")
		mapping = json.loads((args.jobs / "mapping.json").read_text())
		for filename, source in mapping.get("source_files", {}).items():
			if hashlib.sha256(Path(source["path"]).read_bytes()).hexdigest() != source["sha256"]:
				raise ValueError(f"{filename}: source catalog changed after prepare; prepare fresh jobs")
		jobs = [json.loads((args.jobs / f"{locale}.json").read_text()) for locale in mapping["locales"]]
		staged = {locale: json.loads((args.staging / f"{locale}.json").read_text()) for locale in mapping["locales"]}
		candidates = merge(mapping, jobs, staged)
		args.output.mkdir(parents=True)
		for filename, value in candidates.items():
			(args.output / filename).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
		print(f"Wrote {len(candidates)} validated candidate catalogs to {args.output}")


if __name__ == "__main__":
	main()

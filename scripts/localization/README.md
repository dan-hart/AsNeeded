# Optional public-string translation staging

This Python standard-library tool uses the maintainer's already authenticated `codex` CLI. It does not configure providers, read credentials, edit catalogs, or run during builds/CI. Run only with reviewed public app UI strings; never include medication records, account details, or other private user data. Translation output is machine-assisted and still needs language review.

A locale job is JSON:

```json
{
  "locale": "es",
  "entries": [
    {"key": "Log Dose", "source": "Log Dose", "existing": "Registrar dosis"},
    {"key": "AsNeeded", "source": "AsNeeded", "allow_english": "Product brand intentionally remains English"},
    {"key": "doses::one", "source": "%lld doses logged", "plural_group": "doses", "plural_form": "one"},
    {"key": "doses::many", "source": "%lld doses logged", "plural_group": "doses", "plural_form": "many"},
    {"key": "doses::other", "source": "%lld doses logged", "plural_group": "doses", "plural_form": "other"}
  ]
}
```

Use stable opaque keys for variant leaves. `plural_group` and `plural_form` retain enough metadata for a separate catalog merge to construct native plural variations. Each group must contain the full expected cardinal category set for its locale. Source strings retain the count placeholder even when natural translated wording could omit it. The tool never merges staging into source catalogs; that is a separate reviewed step.

Prepared job entries can include `english_variants`, a nonempty list of nonempty strings containing actual display leaves from `en`, `en-US`, `en-GB`, and `en-AU`, plus a literal display key when it differs from the chosen source. Semantic identifiers are excluded. Native plural and substitution leaves use compatible paths and the English `other` fallback; regional spelling variants are never invented by global word replacement. Source and variant comparisons normalize case and whitespace, so copying American English into a job whose source uses British spelling still fails for non-English locales. Only an explicit reviewed `allow_english` reason permits a legitimate identical cognate. Newly prepared variant metadata revalidates existing staging and every reused leaf cache; unrelated valid leaf caches retain their existing content-addressed keys.

`existing` values are retained only if they pass validation. Missing values, invalid placeholders, and unreviewed English copies are translated. Regional English (`en`, `en-AU`, `en-GB`) may legitimately remain unchanged. Identical translations in other locales require a written `allow_english` reason per entry. Review proper nouns, URLs, pure format strings, scientific units, and genuine cognates for that allowlist; do not blanket-allow all unchanged English. A rejected genuine cognate needs an explicit review reason and a rerun.

```sh
python3 scripts/localization/translate_catalog.py /private/tmp/es-job.json \
  --output /private/tmp/localization-staging/es.json \
  --cache /private/tmp/localization-cache
```

For every locale, use a queue manifest with relative job filenames and an explicit required locale inventory. The manifest's locale set must match its jobs exactly, with no duplicates:

```json
{"required_locales":["en","en-AU","en-GB","es"],"jobs":["en-job.json","en-AU-job.json","en-GB-job.json","es-job.json"]}
```

```sh
python3 scripts/localization/translate_catalog.py /private/tmp/jobs/queue.json \
  --queue --output /private/tmp/localization-staging \
  --cache /private/tmp/localization-cache --workers 2
```

Only one locale runs at a time, with at most two simultaneous translation subprocesses. Do not launch multiple queues concurrently. Each request has a 12,000 source/key character maximum by default and a 15-minute timeout. Failures stop the queue by default; add `--keep-going` with `--queue` to finish the remaining independent locales sequentially and print a concise per-locale error summary before exiting nonzero if any failed. The flag also works with queue `--validate-only`; malformed queue/job inventories still fail before processing. Failed locales never write a success staging file, and completed staging and verified leaf caches survive. Rerun the same command to reuse validated content-addressed batch caches. Changing a locale, entry, existing value, allowlist reason, or prompt version creates a different cache key. Completed locale staging files survive failures. Invalid provider responses are saved as `.rejected.json` for inspection and never accepted as cache successes. CLI failures save their exit code only. Missing/malformed JSON and timeouts fail closed.

Repeat the command with `--validate-only` to validate all staged translations without contacting Codex. This checks the exact source-job fingerprint and plural metadata, exact response keys, duplicates, empty values, typed percent placeholders and positional reordering, nested ICU argument names and selectors, HTML tags, URL identity, newline counts, untranslated English, and declared plural category coverage. It does not prove linguistic quality, medication terminology quality, screenshot layout, Markdown rendering, or catalog resource packaging. ICU escaped-brace/apostrophe quoting is not implemented; messages using those features need separate review rather than silently relaxing validation. Locale plural category rules are an explicit table for the supported app locale families; update it against the shipping platform's CLDR behavior when adding languages.

The staging output contains a source-job SHA-256 fingerprint, `locale`, a flat `translations` key/value map, and `plural_entries` metadata. A merge step must revalidate against the original jobs and map each opaque key back to its catalog leaf, preserving extraction metadata, existing valid translations, and native plural structure. Never treat successful translation as authorization to overwrite a catalog blindly.

```sh
python3 -m unittest discover -s scripts/localization -v
```

## Catalog prepare and candidate merge

After the parent syncs compiler-extracted shipping keys into the catalogs, prepare jobs without modifying those files:

```sh
python3 scripts/localization/catalog_jobs.py prepare \
  --catalog AsNeeded/Localizable.xcstrings \
  --catalog AsNeeded/InfoPlist.xcstrings \
  --output /private/tmp/asneeded-localization-jobs
```

Add `--catalog AsNeeded/AppShortcuts.xcstrings` when preparing the optional native App Shortcuts table alongside Localizable and InfoPlist. Native `stringSet.values` phrase arrays are prepared at stable integer index paths and merged back into the same six catalog keys; their order, count, and set metadata remain native, and validated sets receive `state: translated`. English variants match the same phrase index, so another phrase in the set is never treated as an alias of that phrase. The tool does not invent flattened catalog keys. Siri tokens such as `${applicationName}` and `${medication}` may move within translated phrases but must retain exact spelling, dollar signs, and counts. Malformed arrays or unsafe list indexes fail closed.

The output directory must be new. The exact existing Localizable locale inventory plus its source language is retained. Queue order starts Spanish, German, French, Arabic, Hebrew, Persian, Japanese, then the remaining locales. Keys in prompts are short stable hashes; `mapping.json` retains original catalog keys, nested native paths, metadata, source snapshots, and source-file fingerprints. InfoPlist source text comes from its English localization, never from identifier keys such as `NSCameraUsageDescription`.

Optional `--stringsdata-root` arguments read compiler JSON `tables` from explicitly scoped shipping-target directories; `--xliff` accepts flat-key XLIFF exports. Prefer native compiler catalog sync before prepare. Do not point extraction inputs at dependency/test targets. Existing catalog variation/substitution paths remain native. Newly recognized single-count quantity/unit, day, medication, and other noun phrases become native plural trees, using all required locale cardinal categories and retaining typed count placeholders. English singular forms change the noun governed by the count; unrelated plural nouns stay intact. Inspect `mapping.json` templates to review this deterministic English grammar conversion. Four known shipping messages have explicit native multi-count templates: the medication/event summary with an object prefix, the successful-import summary, the historical-source medication/event counts, and partial-import imported/failed counts. Each retains the frozen catalog key and uses positional native substitution wrappers with independent `argNum`, `lld` format specifiers, and per-count plural trees. Other multi-count messages still require compiler-provided substitutions or explicit source work; their count axes are never guessed. Native `%arg` leaf markers and positional substitution names/indices must remain exact. Format-only native wrappers reuse a reviewed identity value without a provider; wrappers containing sentences require translation. Substitution leaf English variants contain only compatible English leaf sources, never an unrelated whole-message key. ICU and native plural formats remain distinct.

For legitimate locale-specific cognates, pass `--reviews /private/tmp/reviewed-identities.json` with this structure:

```json
{"de":{"Localizable.xcstrings":{"Original key":"Reviewed German cognate; identical spelling is correct"}}}
```

Built-in unchanged-text reasons are restricted to reviewed brands/service names, international unit abbreviations, exact public URLs, native substitution wrappers, and format-only punctuation/numbers/placeholders. `shouldTranslate: false` entries require a reviewed identity reason and retain the source verbatim. English source values are accepted as English; English regional values may legitimately remain unchanged. Valid existing translations are preserved, except conversion from a plain count string to native plural forms requires translating the new forms.

Run the queue using `translate_catalog.py` as above. Then generate a separate candidate directory:

```sh
python3 scripts/localization/catalog_jobs.py merge \
  --jobs /private/tmp/asneeded-localization-jobs \
  --staging /private/tmp/localization-staging \
  --output /private/tmp/asneeded-localization-candidates
```

Merge requires all locales, unchanged prepared jobs/source files, valid staging fingerprints, complete plural metadata, and all translation validation gates. It preserves entry comments/extraction metadata and compatible existing leaf metadata. The output directory must be new, so merge cannot overwrite source files. The candidate `.xcstrings` files still require native `xcstringstool` compilation, packaging checks, focused runtime/visual review, and a separate authorized source replacement. This helper neither applies candidates nor changes stored model identifiers.

Validated leaves also have individual caches keyed by locale, opaque key, and exact source text. A response must first pass its entire envelope/schema/exact-key-set check. The runner then validates every leaf, saves only passing values with batch provenance, and reports all invalid leaves together. An invalid envelope never produces leaf-cache successes. Every reuse revalidates current placeholders, identity rules, and English-copy review; changing a review does not waive validation or require retranslating already valid leaves. Each batch saves `.request.json` metadata containing its public source text and locale. These caches contain public app strings only.

For rejected batches created before leaf caching, recover values using the original unchanged locale job and original batch-size setting:

```sh
python3 scripts/localization/translate_catalog.py /private/tmp/asneeded-localization-jobs/es.json \
  --cache /private/tmp/asneeded-localization-cache \
  --output /private/tmp/asneeded-es-backfill-report.json --backfill-rejected
```

Backfill also migrates older successful batch caches. It reconstructs original batch digests from the supplied explicit locale job, checks complete schema/key sets, writes source/locale provenance, and caches only individually valid leaves. It never approves rejected English copies. Keep the original job for this step before regenerating jobs with new review reasons.

Plural cognate reviews must select exact source text, rather than waive every form of a catalog key:

```json
{"es":{"Localizable.xcstrings":{"%g vials":{"%g vial":"Reviewed Spanish singular cognate"}}}}
```

When the English source text is identical across native plural categories, scope a written reason to the specific categories under that exact source:

```json
{"ro":{"Localizable.xcstrings":{"%lld active":{"%lld active":{"few":"Reviewed Romanian few-form adjective active","other":"Reviewed Romanian other-form adjective active"}}}}}
```

This approves only Romanian `few` and `other`; `one` still needs the translated adjective `activ`. Category names must belong to the current locale's native cardinal forms, every selected category needs a nonempty written reason, and category scopes are forbidden on nonplural leaves. A changed source or an unselected category receives no fallback approval. Cache and staging reuse revalidate the current entry, so narrowing an older review cannot retain an incorrect singular copy. Existing exact-source string reasons and nonplural/global identity reasons retain their prior meaning.

This allows the singular `%g vial` only; `%g vials` still needs translation. String review reasons remain supported for nonplural entries and exact globally reviewed proper names. Queue progress prints locale/count completion or failure without dumping translation text. On a failure, valid leaf caches survive and subsequent jobs reuse them after validation.

English display-source resolution uses `en`, then `en-US`, `en-GB`, and `en-AU`, before falling back to a literal source key. Dotted/underscored namespaced identifiers, lower camel-case identifiers, and letter/digit identifiers cannot become display text through that fallback: preparation fails for manual source resolution if no actual English value exists. Existing semantic catalog keys and stale entries remain intact; only their resolved presentation source is translated. For example, `healthkit.auth.detail.authorized` remains the catalog key while its English regional display sentence supplies the translation source. A changed source sentence uses a different leaf-cache fingerprint.

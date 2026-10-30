# Complete 1.2.0 localization implementation plan

> **For agentic workers:** Use superpowers:executing-plans and dispatching-parallel-agents for the independent source domains below. App completion, commit/push, and ASC build upload precede marketing localization.

**Goal:** Make every currently supported locale resolve all user-facing app, notification, widget and Watch text, then prepare localized store artwork and actual UI captures while preserving the English brand “As Needed”.

**Architecture:** Keep the existing string catalog and native Apple localization APIs. Localize presentation values at their owners; preserve user-entered medication names, identifiers, dates, persistence formats, dose calculations, and notification privacy behavior. Share the catalog across shipping bundles. Compiler extraction, placeholder validation, full locale coverage, focused behavior tests, and representative real LTR/RTL captures form separate verification gates. Translations are machine-assisted and are not represented as native-speaker review.

**Tech Stack:** Swift 6, SwiftUI, Foundation string catalogs, WidgetKit, WatchConnectivity, Swift Testing, Python artifact checks, xcodebuild, sim-use, asc.

### 1. Source audit and localization boundaries
- [x] Core services: notifications, guidance, quick-log feedback, intents, user-facing errors/reports, units and formatting. Add focused non-English/placeholder tests without changing stored values or algorithms.
- [x] App UI: navigation titles and dynamic presentation strings, accessibility, reusable label boundaries. Keep medication names and brand names verbatim.
- [x] Widget/Watch: localize all presentation text and include the shared catalog in each shipping target; preserve widget links/actions and Watch message protocol.
- [x] Parent integrates and reviews the three independent source changes before running one build.

### 2. Catalog completion and validation
- [x] Export compiler localizations after source fixes; reconcile every extracted shipping key, including interpolations and InfoPlist strings.
- [x] Translate missing and English-placeholder entries into every existing supported locale. Keep placeholders, units, numbers and safety meaning intact; use plural forms where required. Preserve intentionally untranslated proper nouns.
- [x] Validate locale completeness, nonempty values, placeholder type/count/order, native plural rules, markup and newlines, and target resource packaging.
- [x] Run focused localization regression tests, then the complete existing test plan. Inspect actual results and fix regressions.
- [x] Capture representative Spanish/German/Japanese and Arabic/Hebrew/Persian app screens, including dose entry, large text and Dark Mode, plus an Arabic Watch production-view harness. Inspect RTL flow, alignment, long text, numbers and dates. Verify notification/widget text through native catalog/resource checks; do not claim physical notification delivery or every-language visual certification.

### 3. App delivery gate
- [ ] Commit and push verified app localization changes on task/v1.2.0; verify remote head.
- [ ] Resolve current processed and in-flight build numbers, select the next unused number, archive/export with existing signing assets, upload to ASC and verify VALID/APP_STORE_ELIGIBLE. Do not submit/release the public app.

### 4. Localized marketing assets (after app delivery)
- [ ] Map app locales to ASC-supported locale identifiers; explicitly document locales with no corresponding ASC listing support.
- [ ] Localize all non-brand image text, keep “As Needed” in English, and use fonts that actually cover each script. Preserve exact yellow and source art.
- [ ] Re-seed dedicated synthetic capture simulators and capture each actual translated screen in every device family/locale, including real RTL layouts rather than mirroring English pixels.
- [ ] Render/validate framed assets, inspect each contact sheet, and prepare a reviewable locale/device manifest. Follow the existing approval boundary before replacing newly translated store assets.

No storage schema, keys, medication data, product behavior, or new app feature is part of this work. Do not claim all-language quality from catalog flags or a successful build alone.

### Verified app snapshot before delivery

- All 42 existing locales pass exact-source staging validation, including typed/native plural placeholders, actual regional English variants, protected tokens and explicit source/category-scoped cognate reviews. No missing or unreviewed leaves remain.
- Native compilation includes all 1,728 translatable Localizable keys, 11 translatable InfoPlist keys and 25 native indexed Siri phrase variants in every locale. The English brand remains unchanged. Every validated leaf receives a completed native state, including unchanged source values; compiler key coverage was checked independently of flags.
- The actual simulator app, widget and Watch bundles each contain all 1,728 keys in all 42 locales and report 1.2.0 (322). Nonshipping QA harnesses remain outside the repository and release products.
- Full optimized native test suite: 984 tests passed, 1,157 executions including parameterized cases, no failures or skips. Optional localization-tool tests: 54 passed. Three preflight regression tests also verify French catalog prose is not classified as a graphics-driver change while actual driver changes and catalog secrets remain blocked.
- Machine-assisted translations and curated critical-language review are not native-speaker certification. Representative screenshots and standalone probes are not physical-device delivery proof.
- Stored schemas, identifiers, setting keys and dose calculations remain unchanged. Numeric input and presentation fixes preserve stored values; native plurals keep their numeric arguments.

# Localized 1.2.0 artwork records

The app was delivered first: 1.2.0 (323), source `4001cdfb29329c64232e6b4b21f8edc947ca192e`, processed as `VALID` and `APP_STORE_ELIGIBLE`, selected for the manual-release 1.2.0 draft. See the localization delivery receipt under `docs/testing/`.

This folder stores public, portable text records rather than duplicating the generated image library in Git:

- `manifest.json`: all 1,219 final image hashes, sizes and root-relative provenance references. Its base is the external artifact library containing `locales/`, `raw/` and `common/`.
- `copy.csv`: all 1,302 localized caption and fictional-demo fields compared with their English source.
- `locale-mapping.json`: 42 app locales mapped to 38 distinct supported App Store Connect listing locales, including unsupported/shared-slot cases.

The completed library contains 840 native screenshots and primary framed images, 336 proportional compatibility copies, 42 search creatives and one unchanged English brand-only header. Fresh independent strict validation found zero missing items, pending items or issues. All phone/iPad, Duo and Watch contact sheets were inspected; native long-label wrapping and navigation truncation were preserved rather than edited out. Translations were machine-assisted, not native-speaker certified.

The actual native captures remain identified as build 322 / commit `9b04e83`. The 323 follow-up changes nine close-button accessibility labels and build metadata only; these visible screens and Watch sources are unchanged. No capture code, seed data or QA markers are present in the shipping IPA.

New translated store images are prepared for review and have not been uploaded. Upload requires approval of these new translations, creation of any missing listing-language containers, and a separate check of listing-copy requirements before public App Review. No public submission or release was performed.

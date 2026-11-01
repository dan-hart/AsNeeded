# 1.2.0 localized App Store copy

Public canonical metadata for 37 newly added listing locales plus the unchanged primary English listing. The app name stays **As Needed.** in every locale. Descriptions, release notes, promotional text, subtitles and keywords are localized; support, marketing and privacy URLs retain their working English-source destinations.

All 37 locale candidates passed mechanical checks and a separate machine-assisted review of medical limitations, privacy disclosures, recurring support terms and terminology. This is not native-speaker certification. Keyword phrases already indexed by a localized subtitle were removed without adding replacement claims. Keyword fields meet both the 100-character and conservative 100-UTF-8-byte limits; other fields meet Apple's character limits. Full source/translation text remains directly reviewable in the JSON files.

The upload changed 37 app-info subtitle records and 37 version-localization records. A later cleanup updated only 26 keyword fields. All **342 final field values** across 38 locales were read back exactly. Primary English is unchanged, and all **1,064 screenshots and 76 header/search placements** retain their IDs, checksums, order and active delivery state.

Build **1.2.0 (323)** remains selected. Final public submission validation has zero blocking errors. Its three warnings recommend optional subscription promotional images. The signed-in personal App Store Connect website independently confirms published App Privacy, active Free/Paid Apps agreements and active banking, tax and Digital Services Act statuses. Existing support subscriptions are already approved. Apple also displays a future early-2027 regulated-medical-device declaration reminder; no classification was changed. This work did not submit the app for review or release it.

## Maintenance

The ASC CLI is optional maintenance tooling, not a build or contributor dependency. App and app-info IDs are recorded in `verification-summary.json`. Use the editable app-info record explicitly; never target the live app-info record by position.

```sh
asc metadata validate --dir Design/AppStoreConnect/1.2.0/store-copy/metadata --subscription-app
asc metadata push --app 6714469235 --app-info 34d88d62-9e48-4df9-9f53-d0f117c12a0e --version 1.2.0 --platform IOS --dir Design/AppStoreConnect/1.2.0/store-copy/metadata --dry-run
```

Inspect the preview before applying it. Require zero deletions and no unintended English or asset changes. Keep the unchanged `en-US.json` references: omitting them from an otherwise managed canonical scope can plan deletion of English localizations. Do not use `--allow-deletes` for copy updates. Do not include asset, age-rating, review-information or category scopes for this text-only workflow. A later English edit must be deliberately reconciled with these files before another push.

App binaries and runtime resources were unchanged; no new build is needed for listing-only edits. Locale mapping and artwork provenance live in `../localized-assets/`.

Apple references: [platform metadata limits](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [product-page guidance](https://developer.apple.com/app-store/product-page/). Keyword candidates are qualitative native-language terms, not search-volume or ranking measurements. Representative public localized App Store terminology was checked; competitor names and copied descriptions were not used.

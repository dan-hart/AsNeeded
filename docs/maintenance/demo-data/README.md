# Synthetic demo data

[Download or copy the AsNeeded demo fixture](asneeded-synthetic-demo-data.json). All records are fictional and contain no real personal health information. The fixture is for testing or demonstrating the app from the perspective of someone who logs doses as needed. Medication amounts, saved limits, and notes are test inputs, never dosing guidance.

## Load it into AsNeeded

1. Use a disposable simulator or a dedicated test installation with no personal records or sync to a personal account. Import replaces the installation's medication list and History.
2. Make the JSON available to the test installation's Files picker. In AsNeeded, open **Settings → Data & Privacy → Data Management → Import Data** and select **asneeded-synthetic-demo-data.json**. Expect 15 medications and 233 events. The fixture omits app settings.
3. For the dates below, use the **America/Chicago** timezone and an inclusive custom range from **August 31 through November 22, 2026**. Use custom dates if the History and Trends presets have moved past the scenario. The in-app **Demo Mode** toggle controls display redaction. Leave it off when checking names and turn it on when testing redaction.
4. Use the fixture as a starting point for one task at a time, such as finding an overnight entry, understanding a warning, investigating a logging mistake, or checking that a chart matches History. Record the medication, date range, expected result, and what you observed. Re-import in the disposable installation to restore the baseline after edits.

## Scenarios to check

| What to try | Where to look |
| --- | --- |
| Compare increasing, decreasing, and steady use | In Trends, compare Aug 31–Sep 27, Sep 28–Oct 25, and Oct 26–Nov 22. **Allergy tablet** (cetirizine) has **6 → 12 → 20** recorded doses, **Heartburn chewables** (calcium carbonate) has **20 → 12 → 4**, and **Itchy eyes** (ketotifen) has **8 → 8 → 8**. Scrub across a day with no use and follow the chart back to History. |
| Separate spacing, single-dose, and rolling warnings | For **Headache tablets** (ibuprofen), the entries on **Nov 13 at 5:30 PM and 11:30 PM** are exactly six hours apart and reach the rolling limit. The **Nov 14 at 4:45 AM** entry is too close and pushes the rolling total over the limit across midnight. The **Nov 15 at 2:36 PM** entry exceeds only the single-dose limit. |
| Check the 24-hour cutoff and same-time entries | For **Migraine tablet** (sumatriptan), the **Nov 18 at 6:12 AM** entry stays at the rolling limit because the **Nov 17 at 6:12 AM** entry is exactly 24 hours old. The two **Nov 18 at 1:10 PM** entries have distinct IDs and the same timestamp. The app should show a spacing warning and one rolling total for the pair. |
| Investigate incomplete or inconsistent logs | **Liquid pain reliever** (acetaminophen) has a tablet-unit entry and an entry with no dose amount on **Nov 20**. The **Nov 21 at 1:36 AM** rolling total is unavailable. By **6:24 AM**, the known amounts alone exceed the limit and the rolling warning should report a lower bound. The **Nov 22 at 12:10 PM** entry is clear once the earlier entries expire. **Saline spray** includes a backdated entry with its older nickname. |
| Review the fall-back hour | **Rescue inhaler** (albuterol) has two **Nov 1 at 1:20 AM** entries. They are an hour apart in elapsed time, so the later one has a spacing warning. |
| Check list and inventory states | **Fall cold** and **Old cough syrup** are archived and have September history. **Bathroom cabinet** has zero stock and no history. **Allergy tablet** has a refill record. The fixture also includes a suspected-side-effect record to exercise import without adding to dose totals. |

When updating the fixture, keep records fictional, keep medication and event IDs stable for existing scenarios, and update the dates, expected counts, and results above. Keep the `demoData` notice in the JSON. It describes the fixture and is ignored by AsNeeded's import decoder. Use the checked-in JSON as the source for each import. The file lives outside app resources.

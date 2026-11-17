# Raid loot and points export

`/lm raidexport` opens a local copy dialog listing raid IDs found in retained
ledger/award records. Select one explicitly:

```
/lm raidexport r123abc text
/lm raidexport r123abc csv
```

Replace the example ID with one from the list. Text is a chronological summary;
CSV is the detailed audit-oriented export. Copy it from the existing dialog and
save/import it yourself. Nothing is sent, posted, or written to disk by the addon.
No raid ID exports every raid implicitly. Other raid IDs and unscoped entries
are excluded.

Both formats read the existing synced loot book. CSV includes every retained
award and points entry for the chosen raid, including cancelled/corrected awards,
spends and compensating refunds. Stable columns:

| Column | Meaning |
| --- | --- |
| record_type / entry_kind | `la` award or `lk` ledger; ledger's att/boss/spend/adj/refund kind |
| record_id / author | Existing record ID and stored owner/author |
| recorded_at | Award's recorded timestamp (fallback: record revision); ledger's record revision |
| raid_id / player / item_id | Exact scope, recipient/member and numeric item ID |
| points / cost | Ledger amount or award cost; separate columns prevent treating both as charges |
| state / proof | Existing award state and its recorded evidence |
| boss / encounter | Existing optional boss name and encounter ID |
| reference / spend_id | Existing correction/refund link and award's spend entry ID |
| reason | Recorded reason, when present |

CSV uses CRLF, quoted/escaped text and numeric amounts; UTF-8 names are preserved.
Text that could be interpreted as a spreadsheet formula gets a leading apostrophe.
The export is sorted by recorded timestamp, record type and record ID, without
changing the underlying records. No item-name lookup is required.

## Interpretation and limits

This is a report of **local retained loot/points records**. It is not a complete
attendance list, encounter log, combat-meter report or delivery guarantee. A
person receiving no points and no award does not acquire a row. It includes
whatever peers have delivered to this client; blocked/offline transport or
retention can leave records missing. Awards currently expire after 180 days,
ledger entries after 365; reports can therefore contain a spend whose older
award is no longer retained. No new history store or retention policy is added.
Ledger revisions are not a claim about the original encounter's time. Corrected
awards remain visible alongside their replacements; use state/reference columns
and the existing balances rather than summing both cost and spend columns.

## Verification

Run `npm test`. `tests/raid_export.test.lua` covers scope isolation, unscoped
records, amounts, cancellation/refund visibility, quoting, formula handling,
repeatable ordering, empty/invalid raid IDs, command wiring and read-only use.
No in-game tests have been performed. Manually verify English/Spanish copy-dialog
layout, a full raid-night report, a correction/refund chain and UTF-8 CSV import
in your intended spreadsheet application before adopting it as a guild workflow.

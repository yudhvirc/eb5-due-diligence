---
description: Check an EB-5 document folder for gaps and readiness — missing/incomplete artifacts and the attorney follow-ups they trigger — by inspecting STRUCTURE ONLY. Never reads or transmits financial documents or PII.
argument-hint: "<path to the EB-5 package folder>"
---

Run the **eb5-gapcheck** skill on the folder: `$ARGUMENTS`

Follow `skills/eb5-gapcheck/SKILL.md`:

1. **Locate** the package (use `$ARGUMENTS`; if empty, ask, defaulting to the current folder).
2. **Load** `_eb5_manifest.json` for the expected structure and the authoritative allow-list of
   safe-to-read scaffold files. If there's no manifest, fall back to the canonical taxonomy and
   read only files carrying the `EB5-SCAFFOLD` marker.
3. **Enumerate** what's present using metadata only (Glob + file names/sizes/dates) — never
   open sensitive documents.
4. **Check completeness signals** in scaffold files (checklist statuses, leftover `{{...}}`
   build tokens) and placeholder-scan the working docs (`[[FILL` counts only).
5. **Report** — write `EB5-Readiness-Report.md` (a section-by-section status table, ranked top
   fixes, each with its attorney follow-up) and give a 3-line summary in chat.

**Hard rule (privacy):** inspect structure and completeness only. Do **not** open, read, parse,
quote, or transmit the contents of any financial document or PII (folders `01`/`02`/`03`/`05`
and any pdf/image/spreadsheet/doc). Never write a sensitive value into the report or chat —
describe presence and structure, never content. No network use.

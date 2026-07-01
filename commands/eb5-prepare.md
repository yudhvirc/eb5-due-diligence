---
description: Scaffold a complete, privacy-safe EB-5 petition document package (folders + tailored checklist + blank templates) so the attorney gets a complete set the first time. Never collects financial figures or PII.
argument-hint: "[optional project / regional-center label] [optional target folder]"
---

Run the **eb5-prepare** skill to build an EB-5 petition document package for: `$ARGUMENTS`

Follow `skills/eb5-prepare/SKILL.md`:

1. **Ask** the few non-sensitive questions (location, role, stage, translations via
   AskUserQuestion; then source-of-funds *categories*, dependents yes/no, and an optional
   non-personal label in chat). If `$ARGUMENTS` already supplied a label or path, use it and
   don't re-ask.
2. **Confirm** the target folder (default: a new `EB5-Package-*` subfolder in the current
   directory; don't clobber an existing non-empty folder).
3. **Generate** the folder tree, the tailored `DOCUMENT_CHECKLIST.md`, every folder `README.md`,
   the blank `SOF_Narrative_TEMPLATE.md` / `Path_of_Funds_TEMPLATE.md`, the correspondence log,
   `PRIVACY-AND-HANDLING.md`, `.gitignore`, and `_eb5_manifest.json` — all from
   `assets/prepare/`, with `{{...}}` tokens fully substituted.
4. **Hand off** with the path and the first three things to do, and mention `/eb5-gapcheck` and
   `/eb5-vet`.

**Hard rule:** never ask for, echo, or write any financial figure or PII. You build blank
structure and templates only; the investor fills sensitive values privately. No network use.

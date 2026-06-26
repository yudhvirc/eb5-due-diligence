---
description: Run full independent due diligence on one EB-5 project and produce an HTML report with Immigration and Financial Risk Scores, a Go/No-Go verdict, and inline citations.
argument-hint: "<project or regional-center name> [--ppm <file-or-folder>] [--website <url>]"
---

Run the **eb5-due-diligence** skill end-to-end on the project described by: `$ARGUMENTS`

Follow the orchestrator pipeline in `skills/eb5-due-diligence/SKILL.md`:

1. **Intake & RC resolution** — parse the name and any `--ppm` / `--website` arguments; run
   `scripts/rc_lookup.ps1` to confirm the regional center and pull its local profile.
2. **Claim extraction** — turn the issuer/attorney documents (and/or public materials) into a structured
   claim list; the issuer is the source of the *claim*, never the verification.
3. **Parallel investigation** — fan out the six specialist sub-agents.
4. **Adversarial pass** — run `redflag-adversary` to attack favorable claims and confirm contradictions.
5. **Scoring** — apply `assets/scoring-rubric.json` per `skills/eb5-scoring/SKILL.md`.
6. **Render** — write `findings.json` and run `scripts/render_report.ps1` to produce
   `<project>-eb5-report.html`, then apply the **post-render enhancements** from
   `skills/eb5-report/SKILL.md`: a **"Source documents (locally provided)"** block listing the exact
   filenames you read (or "none received"), and a pointed **owner-facing "Questions to ask in your 1:1"**
   section built from the report's data gaps, with **inline blue/underlined shareable source links**.

If documents are provided via `--ppm <file-or-folder>`, read **every** file first (extract text with
`pdftotext -layout`; the Read tool's PDF path needs `pdftoppm`, often missing on Windows) and record the
exact filenames in `project.source_documents`.

Then give the user a 3-line summary (verdict + the two scores + the single biggest red flag) and the
path to the HTML report. Do not paste the full report into chat.

Remember the core rule: **the attorney's / issuer's documents are not the source of truth** — every
material claim must be independently verified, and unverifiable claims must be penalized and flagged.

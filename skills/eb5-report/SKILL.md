---
name: eb5-report
description: Specification for assembling the EB-5 due-diligence findings.json and rendering the self-contained HTML report (single project and side-by-side comparison), including inline citation rules. Loaded by the eb5-due-diligence orchestrator before the render step.
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Bash
---

# EB-5 Report Assembly & Rendering

The report is produced **deterministically** by `${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1` from a
`findings.json` you assemble. You never hand-write the HTML — you write correct JSON.

## Assembling findings.json
Conform to `${CLAUDE_PLUGIN_ROOT}/schemas/findings.schema.json`. Required top-level keys: `schema_version`
("0.1.0"), `project`, `scores`, `verdict`, `factors` (all 19), `claims`, `red_flags`, `data_gaps`,
`checklist`, `sources`. Also set `generated_at`.

### Citations — the inline-source contract
- Every independent source goes once into `sources[]`. Its **1-based index is the `[n]` marker** rendered
  inline; the renderer links each claim's citations to the matching source by `url|title`.
- Each `sources[]` entry keeps `tier` (0-3), `title`, `url`, `accessed`, and `is_issuer`.
- A claim's `citations[]` should reference the same sources; the renderer auto-adds any it hasn't seen.
- **Issuer sources** must have `is_issuer:true` and tier 0 — they appear in the list labelled
  "(issuer — not independent)" but never satisfy verification.
- **UNVERIFIABLE** claims render with an amber badge and, if no note is given, the text
  "No independent source found; relying solely on issuer representation." Never drop them.

### Factors
Emit all 19 (`I1`-`I9`, `F1`-`F10`) with `subscore`, `confidence`, `summary`, and the `claim_ids` that
back them. For **F1**, put a one-line capital-stack description in `summary` (the renderer surfaces it
above the financial table).

### Checklist
Start from `verification-checklist.json`. For `auto` items, set `status` to `pass` / `fail` / `unknown`
from the evidence. Leave `manual` items as `status:"manual"`.

## Rendering — single project
```
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Findings findings.json -Out "<project>-eb5-report.html"
```
Sections produced, in order: verdict banner (dual gauges + confidence + data-gap warning) · executive
summary · hard-gate panel · immigration breakdown · financial breakdown (+capital-stack note) ·
verification ledger (filterable by verdict) · red-flag log · data-gap log · verification checklist ·
sources · disclaimers.

## Rendering — side-by-side comparison
Produce one `findings.json` per project (e.g. `a.json`, `b.json`), then:
```
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Compare -Findings a.json,b.json -Out eb5-compare.html
```
This emits a summary matrix (best value per column highlighted; an avg-confidence column so a project
doesn't "win" merely by being less verified), a 19-factor heatmap, and each full report embedded as a
collapsible accordion.

## Notes
- The HTML is fully self-contained (inline CSS/JS, no CDN) so it can be emailed or archived.
- The report is decision-support only; the disclaimer block is injected automatically.

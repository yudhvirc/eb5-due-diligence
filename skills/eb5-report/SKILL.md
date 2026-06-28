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

Set `project.source_documents` to an array of the **exact filenames** of any locally-provided documents
you read (PPM, business plan, LPA, subscription, escrow, I-956F notices, investor decks, FAQs). If none
were received, set it to `[]`. These filenames are surfaced in the report (see Post-render enhancements).

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

## Reading locally-provided documents (primary inputs)
When the user supplies offering documents, treat them as **primary inputs** — but they never satisfy
verification on their own (the core rule still holds: independently verify every material claim).
- Extract text with `pdftotext -layout "<file>.pdf" "<out>.txt"`. The Read tool's PDF path needs
  `pdftoppm`, which is often absent on Windows; `pdftotext` (poppler) is reliable. Image-only/scanned
  files (e.g. a fully-executed escrow agreement) yield no text — note that as a limitation.
- Record the **exact filenames** you used in `project.source_documents`, and map each document to the
  project it belongs to.

## Post-render enhancements (apply after render_report.ps1)
`render_report.ps1` is deterministic and does **not** emit these; apply them as a post-render
augmentation (a small Python/PowerShell string-injection pass over the produced HTML). Keep each pass
idempotent. The anchors are stable: per-project accordions are `<details class="acc">` whose body opens
`<div class="body">`; the comparison heatmap header cells are `<th class="num">I1</th>` … `F10`; the
questions/footer is inserted before `<footer>`.

1. **Source documents per section** — at the top of every project's accordion body, and as a
   "Documents reviewed" row in the comparison one-pager, list the locally-provided filenames from
   `project.source_documents`. If none were received, say so explicitly.
2. **One-page summary** (comparison only) — a panel at the very top comparing the **viable**
   (GO/CONDITIONAL) deals across the decision-driving rows: verdict/rank, Immigration & Financial risk,
   raise, I-956F status, regional center, TEA basis, leverage/LTV, repayment guaranty, construction,
   job cushion, documents reviewed, biggest strength, and the single "#1 thing to clear first".
   Highlight the best deal per row; end with a plain-language "Bottom line".
3. **Questions for the meeting** — a section of pointed, **owner-facing 1:1 questions**, one accordion
   per project, built from that project's `data_gaps`, led by a baseline set asked of every owner.
   For **every** question, include two short plain-language lines directly beneath it (assume a
   non-expert reader — define EB-5 jargon like TEA, I-956F, at-risk, redeployment, first-lien):
   - **What this means** — restate the question in everyday language: what you are actually asking for
     and why you would ask it.
   - **Why it matters** — what is at stake for the investor (their green card and/or their $800K), and
     what a straight answer vs. an evasive one tells you.
   Render these as a muted sub-block under each question (e.g. small text in `var(--ink2)`), so the
   question stays scannable but the rationale is one glance away. Append the **shareable source link(s)
   inline** next to the specific question each one backs, styled **blue and underlined**
   (`color:#4ea1ff;text-decoration:underline`) so they read clearly as links.
4. **Heatmap legend + tooltips** — add `title="<factor name>"` to each I1–F10 header cell and a visible
   "What the columns mean" legend mapping every code to its factor name (I = immigration, F = financial).
5. **Source links in the verdict-colored areas** — wherever a verdict is shown in yellow (CONDITIONAL)
   or red (NO-GO), surface that project's shareable source links right there (not only in the bottom
   sources ledger), using the same **blue/underlined ↗** style and drawing from each project's tier-≥2
   `sources[]`:
   - a **"Key sources for this verdict"** block under each project's verdict banner, border-colored to
     match the verdict (`var(--cond)` / `var(--nogo)`);
   - compact source links inside each project's **summary-matrix verdict cell**;
   - inline links on the **one-page summary's** colored claim cells (I-956F status, regional center,
     TEA basis — the "Pending", "NOT SC", "marginal/fragile" type claims).

## Notes
- The HTML is fully self-contained (inline CSS/JS, no CDN) so it can be emailed or archived.
- The report is decision-support only; the disclaimer block is injected automatically.

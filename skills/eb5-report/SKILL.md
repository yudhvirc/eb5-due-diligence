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

**Do not hand-write these — the plugin ships them.** `render_report.ps1` emits the deterministic
skeleton; `${CLAUDE_PLUGIN_ROOT}/scripts/enhance_report.py` layers on the house format:

```
python ${CLAUDE_PLUGIN_ROOT}/scripts/enhance_report.py --html $run/<project>-eb5-report.html --findings $run/findings.json
python ${CLAUDE_PLUGIN_ROOT}/scripts/enhance_report.py --html $run/eb5-compare.html --findings $run/proj1.json,$run/proj2.json,$run/proj3.json
```

Pass the findings files in the **same order** given to `render_report.ps1`. Every pass is **idempotent**
(each writes an HTML comment marker and is skipped if already present), so re-running over an
already-enhanced file is safe. `--only` / `--skip` take a comma-separated pass list:
`heatmap, srcdocs, location, keysources, timeline, disposition, onepager, questions, jargon`. `jargon`
is always forced last so terms introduced by the other passes get icons too.

**The content is data, not code.** Each pass reads `findings.json` plus two bundled assets —
`assets/report-factors.json` (the 19 factor names + their plain-language "why it matters" lines) and
`assets/report-glossary.json` (jargon surface form → one-sentence definition). To change what a report
*says*, write better JSON or add a glossary term; do not fork the script per run. The optional
`one_pager`, `questions`, `timeline` and `decision_summary` blocks in the schema exist precisely so the
per-run editorial content is data.

Everything below is the **specification** those passes implement — read it to know what the JSON must
contain, and consult it if a report needs something the script does not yet cover. If you do extend the
format, add the pass to the script rather than writing a one-off enhancer, so the next run inherits it.
The anchors are stable: per-project accordions are `<details class="acc">` whose body opens
`<div class="body">`; the comparison heatmap header cells are `<th class="num">I1</th>` … `F10`; the
questions/footer is inserted before `<footer>`.

1. **Source documents per section** — at the top of every project's accordion body, and as a
   "Documents reviewed" row in the comparison one-pager, list the locally-provided filenames from
   `project.source_documents`. If none were received, say so explicitly.
2. **One-page summary** (comparison only) — a panel at the very top comparing the **viable**
   (GO/CONDITIONAL) deals across the decision-driving rows: verdict/rank, **location** (city, county,
   state), Immigration & Financial risk, raise, I-956F status, regional center, TEA basis, leverage/LTV,
   repayment guaranty, construction, job cushion, documents reviewed, biggest strength, and the single
   "#1 thing to clear first". Highlight the best deal per row. **Order the columns immigration-first**
   (lowest immigration risk = rank #1, leftmost; financial risk is the secondary tiebreaker), and render
   the per-project findings in that same order so the matrix, heatmap and accordions all match. De-risking
   the green card is the primary objective; capital protection comes after (see `../eb5-scoring/SKILL.md`).
   - **TEA row clarity (write for a non-expert):** label each TEA "solid" (rural) or "shaky"
     (high-unemployment), and for a high-unemployment TEA show the issuer's claimed % next to the
     **county-wide** rate. Then add a **full-width plain-English note row beneath the TEA row** that
     explains, with no jargon, that to get the $800K price the site must be high-unemployment; the
     developer may average just **a few small blocks right around the building** (not the county), which
     is how it reaches e.g. 6.1% while the whole county (the source link) is only ~4–5%; and that if
     USCIS rejects that block choice the investor can lose the $800K pricing and put the petition at risk.
     Avoid "tract bundle" / "gerrymandered" in the investor-facing note — say "hand-picked blocks." This
     prevents the common confusion where the county-data link shows a far lower number than the claimed %.
   - **Do not label high-unemployment "shaky" when the investor has accepted that category, or when the
     designation independently validates.** Keep the two questions separate (see `../eb5-tea-hua/SKILL.md`):
     *is the designation valid* (an eligibility question that can reach hard gate G4) versus *is HUA
     slower than rural* (a **timeline** question only). Where the designation validates, the TEA row
     should say so and the cost belongs in the timeline panel below, not in the risk column.
   - End with a **"Bottom line"** rendered as **bullets — one per deal** (not a dense paragraph), then a
     one-line closing caution.
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
4. **Heatmap legend + tooltips** — a visible "What the columns mean" legend mapping every code to its factor
   name and its plain-language "why it matters" line (I = immigration, F = financial), **and the same full text
   as a `title` tooltip on both the I1–F10 header cells and every data cell**. The tooltip must carry the whole
   legend entry — code, factor name and the why-it-matters line — not just the name, so a reader hovering a
   number gets the explanation without hunting for the legend. Use `&#10;` for line breaks inside the attribute.
   Both the names and the why-lines come from `assets/report-factors.json`; do not retype them.
5. **Source links in the verdict-colored areas** — wherever a verdict is shown in yellow (CONDITIONAL)
   or red (NO-GO), surface that project's shareable source links right there (not only in the bottom
   sources ledger), using the same **blue/underlined ↗** style and drawing from each project's tier-≥2
   `sources[]`:
   - a **"Key sources for this verdict"** block under each project's verdict banner, border-colored to
     match the verdict (`var(--cond)` / `var(--nogo)`);
   - compact source links inside each project's **summary-matrix verdict cell**;
   - inline links on the **one-page summary's** colored claim cells (I-956F status, regional center,
     TEA basis — the "Pending", "NOT SC", "marginal/fragile" type claims).
6. **Project location in every section** — surface each project's physical location (street/city, county,
   state) wherever the project appears: a **Location row** in the one-page summary, a 📍 **location bar**
   at the top of every project's accordion body, and a short "city, state" appended to each project's
   **1:1-questions heading**. The location is load-bearing (it drives the RC-state and TEA checks), so it
   should never be buried.
7. **Inline jargon info icons (not a separate glossary panel)** — explain every term **where it appears**.
   Maintain a map of jargon **surface forms → one-sentence plain-text definition**, then as the **final**
   post-render pass wrap each occurrence in the visible text with a small **clickable info icon placed
   inline, immediately after the term** (no hover — it must work on touch/mobile):
   `<span class="jt">term<button type="button" class="ji" aria-label="What is term?">i</button><span class="ji-pop" role="tooltip"><definition></span></span>`.
   Clicking the icon reveals the definition in a **self-contained popover bubble**. The `.jt` / `.ji` /
   `.ji-pop` CSS **and** the click/dismiss JS (one bubble open at a time; click-outside, Esc, scroll or
   resize closes it; flips up near the bottom edge) live in `assets/report-template.html`, so the report
   needs no per-file script and stays emailable/offline. Add a one-line "tap the info icon next to any
   term" tip near the legend. Implementation guards (important):
   - Wrap **only text nodes** — split on tags and skip anything inside `<style>` / `<script>`, inside tag
     attributes, and inside `<a>` link text (a `<button>` nested in an `<a>` is invalid nested-interactive
     HTML and creates two competing click targets), or you will corrupt the CSS / links.
   - Use a **single longest-match-first** regex sub per text node (so already-injected markup isn't
     re-scanned), with `(?<![\w])…(?![\w])` boundaries so terms aren't matched inside other words.
   - The definition is the **text content** of `.ji-pop` (not an attribute) — **HTML-escape** `&`, `<`, `>`
     and keep it plain text (no markup). Escape the term in the `aria-label` too.
   - If rendering with an older template that lacks the `.ji-pop` rules, inject the CSS + JS once (guard on
     whether `.ji-pop` already exists) so the report is always self-contained.
   Cover **every** acronym/term that appears anywhere (scan the rendered text first). At minimum:
   - *EB-5 program & immigration:* EB-5, reserved category / set-aside, USCIS, Regional Center, RIA, TEA
     (rural vs high-unemployment, incl. **why a TEA can show a high % while the county link shows a much
     lower one** — hand-picked blocks vs county-wide), NCE, JCE, at-risk / sustainment, redeployment,
     conditional permanent resident, adjudication.
   - *USCIS forms:* I-956F, I-956G, I-526E, I-829, I-131 / I-765, NIW (and why it doesn't exist for
     EB-5), NOIT.
   - *Money & deal structure:* capital stack, senior / first lien, second lien / subordinate, the
     "1st-lien-once-fully-funded; 2nd-until-then" nuance, pari passu / participation, intercreditor
     agreement, first-loss, LTV, loan-to-cost, mezzanine / bridge, tranche, NOI, cap rate, DSCR, RevPAR,
     GMP contract, SOFR, stabilization, takeout, escrow / fund administrator, the repayment / completion
     / denial guaranties, SBLC, job cushion.
   - *Securities & background checks:* PPM, LPA, accredited investor, Reg D / Form D, EDGAR,
     FINRA / BrokerCheck / CRD, source-of-funds.
   - *How this report scores:* the 0–100 risk sub-score, the 0–3 confidence level, the hard gates
     (G1–G5), and Immigration vs Financial risk.

8. **Green-card timeline panel (required for every high-unemployment project)** — a standalone panel,
   sourced from `../eb5-tea-hua/SKILL.md` Part 2, that tells the reader in plain language what the HUA
   category costs them **in time**. It must state, with run-time-current figures and links:
   - **Pool size** — rural 20% of the ~10,000 annual EB-5 visas vs **high-unemployment 10%**;
     infrastructure 2%. Unused reserved visas roll into the same category the next year, then unreserved.
   - **Priority processing** — the RIA directs USCIS to prioritise **rural**; **HUA gets none**. This is
     the biggest practical difference.
   - **Where it actually bites** — most of rural's advantage lands at the **I-956F** stage, so **if this
     project's I-956F is already approved that advantage is largely spent**; say so explicitly rather
     than letting the headline overstate the remaining cost. The live difference for a new investor is at
     the **I-526E** stage — quote the **current USCIS processing-times page** and label it a moving
     number. **No category difference at I-829.**
   - **Retrogression** — the smaller pool fills first; check the **current Visa Bulletin** for the
     investor's chargeability area (material for **India / China**, usually not otherwise).
   - **Two calendar items** — file the I-526E early, and file **before the designation window closes**;
     render the computed **I-956F filing date + 2 years** as a hard date.
   Place this panel next to the TEA discussion, and frame it as a **schedule disclosure, not a risk
   finding** — the eligibility question lives in I4 and is scored there.
9. **Risk disposition on every red flag** — where a finding carries the calibration fields from
   `../eb5-risk-calibration/SKILL.md`, render them so a reader can triage in one pass:
   - A **disposition chip** on each red flag — `ACCEPT` (muted/green), `CAUTION` (amber), `MITIGATE`
     (amber, bolded), `AVOID` (red) — with the probability band and severity class as a small
     `P2 · S4 · 20–50% likely · green-card-fatal` sub-line, and the `basis` (cited base rate, or
     "judgment") beside it so an uncited band is visibly an estimate.
   - For every **CAUTION / MITIGATE**, print the `mitigation` string as an **action line** — the exact
     document or written change to request. Never render a MITIGATE without one.
   - A **"What you can live with" panel** near the top, built from `decision_summary`: the `one_line`,
     then three short lists — **Must clear before wiring**, **Acceptable as-is** (state plainly that
     these should *not* delay the decision), and **Cannot be resolved in time** (what the reader is
     accepting if they proceed anyway).
   - Where a hard gate fired, show its **`gate_class`** — *structural* (a wall) or *curable* (the
     opening of a negotiation), G5 split into G5-doc / G5-fact. Keep the verdict itself at NO-GO; the
     class tells the reader what to do, it never promotes the verdict.
   - In a **comparison**, add a **residual-risk ordering** beneath the immigration-first ranking whenever
     the two differ — ranking by what remains after obtainable mitigations — with a one-line explanation
     of why they differ.

**Ordering:** enhancement 7 (inline jargon icons) always runs **last**, after 8 and 9, so the terms
introduced by the new panels get icons too. `enhance_report.py` enforces this regardless of `--only`
order.

## Colour coding (non-negotiable)

**Colour encodes absolute quality. Being the best of a set never earns a quality colour.**

A comparison always has a leftmost column, and in a bad field that column is still bad. If "best in
row" is painted green, a NO-GO that happens to be the least-bad option reads as a pass — which is the
single most misleading thing this report could do.

- **Green (`--go`)** — genuinely good in absolute terms. **Amber (`--cond`)** — caution. **Red
  (`--nogo`)** — bad. Risk scores band at **≤35 / 36–60 / >60**, matching the verdict matrix.
- **Rank is blue** (`--accent`), never green: a thin inset bar on the better one-pager cell, and the
  `.best` outline in the summary matrix. Blue means *best of this set*, which is not the same as good.
- `enhance_report.py` enforces this mechanically for the two cases it can detect: a cell containing a
  **verdict** (GO / CONDITIONAL / NO-GO) or an **`N/100` risk score** is coloured from its own value and
  ignores `good` for colour, taking the rank marker instead.
- For every other cell, `good: true` is the author's assertion that the value **is genuinely
  favourable**, not merely better than the other column. Do not set it on a mixed or partly-negative
  cell — "3 of 4 sites verified, the fourth fails" is not a green cell.
- Every colour already carried by the renderer is absolute and must stay that way: verdict chips, the
  heatmap `ScoreColor` ramp, gauge bars, severity dots, and the disposition chips (ACCEPT green /
  CAUTION amber / MITIGATE orange / AVOID red).
- The one-pager carries a visible **colour key** stating all of this, so the reader never has to infer it.

## Checking the output
After enhancing, verify (the script's own summary line reports which passes applied — a pass that
silently no-ops usually means the JSON block it reads is missing):
- **Tag balance** — `<div>`/`<span>`/`<details>`/`<table>` open and close counts match.
- **The `<style>` block is untouched** — no `<span class="jt">` before the first `</style>`. A jargon
  pass that leaked into the CSS corrupts the whole report.
- **No `<button>` inside an `<a>`** — nested interactive elements are invalid and create two competing
  click targets.
- **Each term wrapped once** — a term should appear with an icon on its first occurrence only.
- **Re-running changes nothing** — the byte count after a second run must be identical.

## Notes
- The HTML is fully self-contained (inline CSS/JS, no CDN) so it can be emailed or archived.
- The report is decision-support only; the disclaimer block is injected automatically.

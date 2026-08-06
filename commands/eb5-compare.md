---
description: Vet several EB-5 projects and produce a side-by-side comparison report (summary matrix, factor heatmap, and full embedded reports).
argument-hint: "<projectA> | <projectB> | <projectC> ...  (separate projects with | )"
---

Compare multiple EB-5 projects. Projects are given in `$ARGUMENTS`, separated by `|`.

**Create today's output folder first.** Before writing any artifacts, make a **new dated run folder** in
the working directory — `eb5-run-YYYYMMDD` (today's date). Run again the same day? Reuse it, or add a short
suffix / project slug so nothing is clobbered (e.g. `eb5-run-YYYYMMDD-b`, `eb5-run-YYYYMMDD-compare`). Put
**all** outputs — every `projN.json`, the rendered `eb5-compare.html`, and any post-render enhancement
script — **inside that folder**, so each day's run is self-contained and never overwrites a prior one (see
the unique-output-filenames rule). PowerShell: `$run="eb5-run-$(Get-Date -Format yyyyMMdd)"; New-Item
-ItemType Directory -Force -Path $run` (bash: `run="eb5-run-$(date +%Y%m%d)"; mkdir -p "$run"`).

**If the user provides a documents folder/files:** first read **every** file in it (extract text with
`pdftotext -layout`, since the Read tool's PDF renderer needs `pdftoppm`, often missing on Windows).
Map each document to its project, and record the **exact filenames** in each project's
`project.source_documents`. Treat them as primary inputs but still independently verify every claim.

For **each** project, run the full **eb5-due-diligence** pipeline (see `commands/eb5-vet.md` and
`skills/eb5-due-diligence/SKILL.md`) and write its own findings file **inside today's run folder**:
`$run/proj1.json`, `$run/proj2.json`, ….

Then render the comparison (output into the same run folder):

```
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Compare -Findings $run/proj1.json,$run/proj2.json[,...] -Out $run/eb5-compare.html
```

The comparison report shows a summary matrix (best value per column highlighted, with an avg-confidence
column so a project does not "win" merely by being less verified), a 19-factor heatmap, and each full
project report as a collapsible accordion.

**Then apply the post-render enhancements** (see `skills/eb5-report/SKILL.md` → "Post-render
enhancements"). For a comparison, always add: (1) a **"Source documents (locally provided)"** block at
the top of each project's section plus a "Documents reviewed" row in the one-pager; (2) a **one-page
summary** of the viable (GO/CONDITIONAL) deals at the very top, **ordered immigration-first** (best
immigration risk leftmost; render the findings in that order so the matrix, heatmap and accordions match); (3) an **owner-facing "Questions to ask
in your 1:1"** section built from each project's data gaps, with **inline blue/underlined shareable
source links** — and, under **every** question, a plain-language **"What this means"** and **"Why it
matters"** sub-line (assume a non-expert reader; define EB-5 jargon); (4) the **heatmap legend +
I1–F10 hover tooltips**; and (5) **source links in every verdict-colored area** — a "Key sources for
this verdict" block under each project's banner, links in the summary-matrix verdict cells, and inline
links on the one-page summary's yellow/red claim cells; (6) **disposition chips** on every red flag plus
a per-project **"What you can live with"** panel (must-clear-before-wiring / acceptable-as-is /
cannot-be-resolved-in-time), from `skills/eb5-risk-calibration/SKILL.md`; and (7) for every
**high-unemployment** project, the **green-card timeline panel** from `skills/eb5-tea-hua/SKILL.md`.

**Calibrate before you rank.** Run `skills/eb5-risk-calibration/SKILL.md` over each project's red flags —
probability band × severity class → ACCEPT / CAUTION / MITIGATE / AVOID — and classify any fired gate
**structural** (a wall) or **curable** (the opening of a negotiation). Every real offering has defects;
the value of a comparison is separating the few that should stop a decision from the many that should be
noted and moved past. Do not label a **high-unemployment** TEA a defect where the designation
independently validates — that cost is a **timeline** matter and belongs in the timeline panel.

Give the user a short ranking with the key trade-offs and the path to the report
(`<run-folder>/eb5-compare.html`). **Rank
immigration-first:** order projects by the immigration composite (lower = better), with financial risk as
the secondary tiebreaker — de-risking the green card is the primary objective, capital protection comes
after (see `skills/eb5-scoring/SKILL.md` → "Priority: immigration first, financial second"). When the
user is deciding under a **deadline**, also give the **residual-risk ordering** (rank by what remains
after obtainable mitigations) wherever it differs from the raw one, and say in a line why. If every
candidate calibrates to AVOID, say "none of these" plus what to look for next — do not present a
least-bad pick as viable. Keep the
core rule in force for every project: independently verify; never trust issuer/attorney paper.

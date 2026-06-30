---
description: Vet several EB-5 projects and produce a side-by-side comparison report (summary matrix, factor heatmap, and full embedded reports).
argument-hint: "<projectA> | <projectB> | <projectC> ...  (separate projects with | )"
---

Compare multiple EB-5 projects. Projects are given in `$ARGUMENTS`, separated by `|`.

**If the user provides a documents folder/files:** first read **every** file in it (extract text with
`pdftotext -layout`, since the Read tool's PDF renderer needs `pdftoppm`, often missing on Windows).
Map each document to its project, and record the **exact filenames** in each project's
`project.source_documents`. Treat them as primary inputs but still independently verify every claim.

For **each** project, run the full **eb5-due-diligence** pipeline (see `commands/eb5-vet.md` and
`skills/eb5-due-diligence/SKILL.md`) and write its own findings file: `proj1.json`, `proj2.json`, ….

Then render the comparison:

```
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Compare -Findings proj1.json,proj2.json[,...] -Out eb5-compare.html
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
links on the one-page summary's yellow/red claim cells.

Give the user a short ranking with the key trade-offs and the path to `eb5-compare.html`. **Rank
immigration-first:** order projects by the immigration composite (lower = better), with financial risk as
the secondary tiebreaker — de-risking the green card is the primary objective, capital protection comes
after (see `skills/eb5-scoring/SKILL.md` → "Priority: immigration first, financial second"). Keep the
core rule in force for every project: independently verify; never trust issuer/attorney paper.

---
description: Vet several EB-5 projects and produce a side-by-side comparison report (summary matrix, factor heatmap, and full embedded reports).
argument-hint: "<projectA> | <projectB> | <projectC> ...  (separate projects with | )"
---

Compare multiple EB-5 projects. Projects are given in `$ARGUMENTS`, separated by `|`.

For **each** project, run the full **eb5-due-diligence** pipeline (see `commands/eb5-vet.md` and
`skills/eb5-due-diligence/SKILL.md`) and write its own findings file: `proj1.json`, `proj2.json`, ….

Then render the comparison:

```
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Compare -Findings proj1.json,proj2.json[,...] -Out eb5-compare.html
```

The comparison report shows a summary matrix (best value per column highlighted, with an avg-confidence
column so a project does not "win" merely by being less verified), a 19-factor heatmap, and each full
project report as a collapsible accordion.

Give the user a short ranking with the key trade-offs and the path to `eb5-compare.html`. Keep the
core rule in force for every project: independently verify; never trust issuer/attorney paper.

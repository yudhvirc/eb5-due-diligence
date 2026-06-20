# Examples / smoke test

These files demonstrate the report output and double as an offline smoke test for the
renderer (no web, no LLM).

- `sample-findings-A.json` — a realistic **CONDITIONAL** project (weakly-evidenced financials).
- `sample-findings-B.json` — a **NO-GO** project (two hard gates: invalid rural set-aside + confirmed job shortfall).
- `sample-report-A.html` — the single-project report rendered from A.
- `sample-compare.html` — the side-by-side comparison of A and B.

## Regenerate (Windows PowerShell or pwsh)

```powershell
# Single report
powershell -NoProfile -ExecutionPolicy Bypass -File ../scripts/render_report.ps1 `
  -Findings ./sample-findings-A.json -Out ./sample-report-A.html

# Comparison
powershell -NoProfile -ExecutionPolicy Bypass -File ../scripts/render_report.ps1 -Compare `
  -Findings "./sample-findings-A.json,./sample-findings-B.json" -Out ./sample-compare.html
```

Open the `.html` files in any browser — they are fully self-contained (no internet needed).
The `findings.json` shape is defined in `../schemas/findings.schema.json`.

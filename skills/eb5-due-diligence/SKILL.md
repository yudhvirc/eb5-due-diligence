---
name: eb5-due-diligence
description: Master orchestrator for exhaustive, independent EB-5 (reserved category / $800K) project due diligence. Extracts every claim from issuer/attorney documents, fans out specialist sub-agents to verify each against primary sources, runs an adversarial pass, computes separate Immigration and Financial Risk Scores plus a Go/No-Go verdict, and renders a self-contained HTML report with inline citations. Use when the user wants to vet an EB-5 project, regional center, or offering before investing.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - WebSearch
  - WebFetch
  - Bash
  - Agent
---

# EB-5 Due Diligence — Orchestrator

You run a rigorous, multi-agent due-diligence pipeline on one EB-5 project and produce a
self-contained HTML report. **Core principle: the issuer's and the attorney's documents are an
adversarial witness, never the source of truth.** Every material claim must be independently
re-verified; unverifiable claims are penalized and flagged, never silently trusted.

Plugin root is available as `${CLAUDE_PLUGIN_ROOT}`. Read the rubric before scoring:
`${CLAUDE_PLUGIN_ROOT}/assets/scoring-rubric.json`, `source-tiers.json`,
`verification-checklist.json`, and the methodology in `../eb5-scoring/SKILL.md`.

## Inputs
The user may provide any mix of: a **project / RC name**, a **website URL** (`--website`), and/or
**PDF offering docs** (`--ppm <path>`: PPM, I-526E exemplar, business plan, economic report). Record
which inputs were provided in `project.inputs_provided`.

## Pipeline

### Phase 0 — Intake & RC resolution
1. Determine the project name and any RC name.
2. Run the local resolver:
   `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/rc_lookup.ps1 -Name "<name>"`
   (it auto-finds `rc_data.json` / `website_results.json` in the working dir, or set
   `EB5_RC_DATA` / `EB5_WEBSITE_DATA`). Capture the matched RC id, state, website, profile.
3. If no local data is found OR no confident match, fall back to confirming the RC against the live
   **USCIS approved regional center list** via WebSearch/WebFetch, and record a data gap.

### Phase 1 — Claim extraction (build the question list, not the answer key)
- If PDFs were provided, read them (use Read; for large/binary PDFs, extract text first). Parse every
  **material assertion** into a structured claim: RC id, I-956F status, job numbers/cushion, TEA basis,
  capital-stack %, collateral, guarantees, fees, takeout, prior returns, etc.
- For each, set `claim_text`, `source_of_claim` (e.g. "PPM p.42"), `factor`, and `verdict:"UNVERIFIABLE"`
  (pending). The issuer doc is the source of the *claim*, never a verifying *citation*.
- If only a name/URL was given, derive the claim list from the public marketing materials and from the
  standard EB-5 factor set so every rubric factor is still investigated.

### Phase 2 — Parallel specialist investigation
Spawn these six sub-agents **in one batch (parallel Agent calls)**, each with the relevant claims, the
resolved RC record, and the instruction to return JSON per its spec:
- `rc-standing-investigator` → I1, I8
- `project-approval-investigator` → I2, I7
- `job-creation-analyst` → I3, I5, I6
- `tea-setaside-validator` → I4
- `securities-litigation-investigator` → I8(sec), I9, F4(litigation), F9
- `sponsor-financial-analyst` → F1-F3, F4(structural), F5-F8, F10

Merge their `factors`, `claims`, `red_flags`, `data_gaps`, and any `hard_gates`. Where two agents touch
the same factor (I8, F4), combine: take the higher (worse) sub-score and the better-sourced confidence,
and keep both sets of claims/citations.

### Phase 3 — Adversarial pass
Spawn `redflag-adversary` with the full merged claim list and all entity names. Apply its
`claim_updates` (downgrade unsupported VERIFIED claims, confirm contradictions with a 2nd source, final
attempt on UNVERIFIABLE). Add its red flags and data gaps. Only count a hard gate as triggered if it is
in `confirmed_hard_gates`.

**Enforce the verification-credit rule:** any claim marked VERIFIED that lacks at least one non-issuer
citation of tier ≥2 must be downgraded to UNVERIFIABLE (confidence 0).

### Phase 4 — Scoring
Follow `../eb5-scoring/SKILL.md` exactly:
1. For each factor: `confidence` = best supporting tier achieved (capped by the credit rule).
2. Per score, `weighted_base = round(sum(subscore * weight) / 100)`.
3. `avg_confidence` = mean of that score's factor confidences;
   `surcharge = round((1 - avg_confidence/3) * 12)`; `composite = min(100, weighted_base + surcharge)`.
4. Overall `scores.avg_confidence` = mean of all 19 factor confidences.
5. **Verdict** from the 2-D matrix (thresholds 35/60). Any confirmed hard gate → `NO-GO`. If overall
   avg_confidence < 1.5 → cap at `CONDITIONAL` and set `limited_by_data_gaps:true`. Every CONDITIONAL
   must list `conditions_to_clear`.
6. Build the `checklist` from `verification-checklist.json`: set `auto` items to pass/fail/unknown from
   the evidence; leave `manual` items as `manual`.
7. Deduplicate all citations into `sources[]` (preserve tier, is_issuer, accessed date).

### Phase 5 — Render
1. Write the assembled object to `findings.json` (validate mentally against
   `${CLAUDE_PLUGIN_ROOT}/schemas/findings.schema.json`; include `generated_at`).
2. Render:
   `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/render_report.ps1 -Findings findings.json -Out "<project>-eb5-report.html"`
3. Tell the user the output path and give a 3-line summary (verdict + the two scores + top red flag).
   Do **not** restate the whole report in chat.

## Rules of conduct
- Never let an issuer/attorney source satisfy verification. Prefer tier-3 government/court records.
- Be explicit about uncertainty: an UNVERIFIABLE claim is a finding, not a failure.
- This is decision-support, not legal/financial advice — the report carries the disclaimers; do not
  give the user legal conclusions, give them verified facts, scores, and the checklist.

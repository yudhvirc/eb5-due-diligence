---
name: eb5-scoring
description: Reference methodology for computing the EB-5 Immigration Risk Score, Financial Risk Score, confidence, uncertainty surcharge, hard gates and the Go/No-Go verdict. Loaded by the eb5-due-diligence orchestrator and the specialist agents to keep scoring consistent with assets/scoring-rubric.json.
user-invocable: false
allowed-tools:
  - Read
---

# EB-5 Scoring Methodology

This is the human-readable companion to `${CLAUDE_PLUGIN_ROOT}/assets/scoring-rubric.json`, which is
the machine-readable single source of truth. **If they ever disagree, the JSON wins.** Always read the
JSON for the exact weights and thresholds.

## Direction
All scores run **0 = lowest risk (best) → 100 = highest risk (worst)**, for both sub-factors and the two
composite scores. Lower is better everywhere.

## Confidence (per factor, 0-3)
- **3** primary government/court record (USCIS lists & notices, I-956F/G data, SEC EDGAR, PACER,
  Census, BLS, county recorder, OFAC).
- **2** reputable independent third party (established press, independent market data, independent
  auditor/fund administrator).
- **1** single weak/uncorroborated third party.
- **0** issuer-only or nothing → the claim is **UNVERIFIABLE**.

**Credit rule (non-negotiable):** a claim may only reach confidence ≥2 if a **non-issuer** source of
tier ≥2 corroborates it. The issuer corroborating itself does not count. Otherwise downgrade to
UNVERIFIABLE (confidence 0).

## Sub-factor → composite
1. Each factor has a `subscore` (0-100) and a `confidence` (0-3).
2. `weighted_base = round( Σ(subscore_i × weight_i) / 100 )` over that score's factors (weights sum 100).
3. `avg_confidence` = mean of that score's factor confidences.
4. **Uncertainty surcharge** = `round( (1 − avg_confidence/3) × 12 )`. This is the penalty for relying on
   issuer paper: max +12 when nothing is independently verified, 0 when everything is tier-3.
5. `composite = min(100, weighted_base + surcharge)`.

Compute the **immigration** composite over I1-I9 and the **financial** composite over F1-F10
independently — never blend them.

### Weights (must sum to 100 each; confirm against the JSON)
- Immigration: I1 16, I2 15, I3 14, I4 14, I5 10, I6 8, I7 9, I8 9, I9 5.
- Financial: F1 15, F2 8, F3 11, F4 14, F5 12, F6 11, F7 12, F8 6, F9 6, F10 5.

## Hard gates (any one → NO-GO, regardless of scores)
G1 RC terminated/debarred · G2 I-956F denied/withdrawn · G3 SEC/fraud enforcement vs principals ·
G4 proven TEA/set-aside misqualification · G5 confirmed material misrepresentation (a CONTRADICTED
material claim **confirmed by a second independent source** in the adversarial pass). When a gate fires,
set its related factor sub-score to 100.

## Priority: immigration first, financial second
**Immigration de-risking is the PRIMARY objective** (protecting the green card); **financial risk is SECONDARY** (protecting capital). This drives two rules:
- **Verdict:** the immigration band gates the outcome. Financial risk **alone never forces a NO-GO** when immigration risk is *low* — such a deal is **CONDITIONAL** with the financial problems listed as `conditions_to_clear`. Immigration risk that is *high* is always a NO-GO.
- **Ranking (comparisons):** rank projects by the **immigration composite first** (lower = better), then by the financial composite as the tiebreaker. Surface the most immigration-de-risked deals at the top of the one-pager and matrix.

## Verdict (2-D matrix, thresholds 35 / 60)
Let `imm` and `fin` be the two composites. Band each as low (≤35), mid (36-60), high (>60). The matrix is **immigration-primary**: a low-immigration row is never NO-GO from financial risk alone.

| | fin low | fin mid | fin high |
|---|---|---|---|
| **imm low** | GO | CONDITIONAL | CONDITIONAL |
| **imm mid** | CONDITIONAL | CONDITIONAL | NO-GO |
| **imm high** | NO-GO | NO-GO | NO-GO |

(Change vs a symmetric matrix: **imm-low + fin-high is CONDITIONAL, not NO-GO** — a strongly immigration-de-risked deal is flagged, not killed, by financial risk alone.)

Overrides:
- Any confirmed hard gate → **NO-GO**.
- Overall `avg_confidence < 1.5` → cap the verdict at **CONDITIONAL** and set `limited_by_data_gaps`.
- Every **CONDITIONAL** must enumerate `conditions_to_clear` (the specific items that would move it to GO).

## Worked sketch
If immigration weighted_base = 28 and imm avg_confidence = 2.0 → surcharge = round((1−0.667)×12)=4 →
imm composite = 32 (low band). If financial weighted_base = 47, fin avg_confidence = 1.0 →
surcharge = round((1−0.333)×12)=8 → fin composite = 55 (mid band). Matrix(imm low, fin mid) =
**CONDITIONAL**, with conditions to clear listed.

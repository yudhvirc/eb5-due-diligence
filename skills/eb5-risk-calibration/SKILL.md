---
name: eb5-risk-calibration
description: Converts EB-5 findings into decision-grade risk — a probability band and a severity class for every red flag, a deterministic ACCEPT/CAUTION/MITIGATE/AVOID disposition, curable-vs-structural classification of the hard gates, and a time-pressure protocol for investors who must choose between real offerings on a deadline rather than wait for an ideal one. Loaded by the eb5-due-diligence orchestrator after the adversarial pass and before scoring.
user-invocable: false
allowed-tools:
  - Read
  - WebSearch
  - WebFetch
---

# EB-5 Risk Calibration — How Big Is It, and Can I Live With It?

The risk scores answer *"how bad is this deal?"* They do **not** answer the question an investor with a
deadline is actually asking: *"is **this specific problem** likely to hurt me, how badly, and can I
proceed anyway?"* This skill answers that.

**Framing rule.** Every real EB-5 offering has defects. An investor comparing four live deals with a
decision due in weeks cannot hold out for a clean one, because there isn't one. The job is therefore
**not** to list everything wrong — it is to separate the few findings that should actually stop a
decision from the many that should be noted and moved past. A report that flags forty things without
ranking them by consequence has pushed the hard work back onto the reader.

**What this does not do.** Calibration is an **overlay**, not an override. It never changes a sub-score,
a composite, or a hard-gate verdict. It sits alongside them and tells the reader what to *do*.

---

## Step 1 — Probability band

For each red flag, state how likely the **adverse outcome** is — not how likely the fact is. The fact
may be certain while its consequence is not.

| Band | Likelihood | Meaning |
|---|---|---|
| **P4** | **>80% — near-certain** | Already true on the record. Not a forecast: the RC *is* terminated, the TEA *does* fail on the filing-vintage data, the permits *do not* exist. |
| **P3** | 50–80% — likely | The mechanism is in place and nothing plausible prevents it. |
| **P2** | 20–50% — realistic | A recognised, regularly-observed failure mode with this structure. |
| **P1** | 5–20% — unlikely | Possible; needs an additional adverse event. |
| **P0** | <5% — remote | Theoretically available to an adjudicator or a court but rarely exercised. |

**Anchor the band to a base rate, and cite it.** Where a published rate exists — I-526E approval/denial
and RFE rates, I-956F adjudication outcomes, regional-center termination counts against the total
approved, USCIS processing times — look it up at run time from USCIS data and cite it as the basis.
Where none exists, say `basis: "judgment — no published base rate"` rather than manufacturing a number.
An uncited probability band is a guess wearing a uniform; label it as one.

**Do not confuse a data gap with a defect.** Under time pressure this is the most common error, in both
directions. Ask: *would evidence exist here if the claim were true?*
- **Probative absence** → score it: no I-797C for a claimed I-956F approval; no permits for a project
  marketed as under construction; no RC on the live USCIS list.
- **Non-probative absence** → do not penalise it as if it were a finding: no Form D where Reg S or
  506(b) makes one unnecessary; no third-party guaranty (most EB-5 deals lack one); no press coverage of
  a small private developer.

## Step 2 — Severity class

State what happens **if** it materialises. Immigration consequences outrank financial ones, consistent
with `../eb5-scoring/SKILL.md`.

| Class | Consequence |
|---|---|
| **S4** | **Green-card fatal or total loss** — petition denial with no cure, no path to I-829, or complete loss of the $800,000. |
| **S3** | **Severe** — RFE/NOID carrying real denial risk, a multi-year delay, or loss of the majority of capital. |
| **S2** | **Moderate** — recoverable: an RFE answerable from documents already in hand, a redeployment, a delayed or partial return of capital. |
| **S1** | **Minor** — cost, friction or annoyance. Does not change the outcome. |

## Step 3 — Disposition (deterministic)

Read the disposition off the grid. Do not freehand it.

|  | **P0** <5% | **P1** 5–20% | **P2** 20–50% | **P3** 50–80% | **P4** >80% |
|---|---|---|---|---|---|
| **S4** fatal | CAUTION | MITIGATE | **AVOID** | **AVOID** | **AVOID** |
| **S3** severe | ACCEPT | CAUTION | MITIGATE | **AVOID** | **AVOID** |
| **S2** moderate | ACCEPT | ACCEPT | CAUTION | MITIGATE | MITIGATE |
| **S1** minor | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

- **ACCEPT** — note it and move on. **This finding must not delay the decision.** Say that in the report.
- **CAUTION** — proceed, but complete one **named check you can actually finish before wiring**. State
  the check and how long it takes.
- **MITIGATE** — proceed **only if** you obtain a **specific written change or document**. State exactly
  what to ask for, and what a refusal tells you. A refusal to put in writing something the sponsor
  asserts verbally is itself a finding — usually upgrading the probability band by one.
- **AVOID** — no investor-level mitigation exists. Walk.

Every MITIGATE **must** carry a concrete `mitigation` string that is obtainable by an individual
investor before closing. "Ask the sponsor to be more transparent" is not a mitigation. "Require the
escrow agreement to be amended so release occurs on I-526E approval, not filing" is.

---

## Step 4 — Curable vs structural gates

A NO-GO on a curable gate is the opening of a negotiation. A NO-GO on a structural gate is a wall. The
report must say which it is, because the two demand completely different responses from a reader who is
short of time.

| Gate | Class | Why |
|---|---|---|
| **G1** RC terminated / debarred | **Structural** | Nothing the investor or sponsor can do inside the decision window. |
| **G2** I-956F denied / withdrawn | **Structural** | The sponsor may refile, but that is a new project on a new clock — not a cure for this decision. |
| **G3** SEC / fraud enforcement vs principals | **Structural** | Goes to the principals, not the paperwork. |
| **G4** proven TEA / set-aside misqualification | **Structural** | The $800,000 price is fixed by the record **as of filing**. It cannot be repaired retroactively. An amended or refiled I-956F on a valid basis resets the clock — a different deal, not a cure. |
| **G5** confirmed material misrepresentation | **Split — classify it** | See below. |

**G5 sub-classification** (always state which):
- **G5-doc** — a *document* was mischaracterised (an "approval letter" that approves nothing; a notice
  cited for a proposition it does not support). **Potentially curable**: the sponsor can produce the
  real document. If they produce it, the gate clears and the finding drops to a disclosure-quality note.
  If they will not, the gate hardens and the probability of *other* misstatements rises.
- **G5-fact** — a *state of the world* was misstated ("under construction" with zero vertical permits;
  "300+ approvals" from a regional center that post-dates the form). **Not curable by explanation.** It
  can only cure by the world changing. Even then, the misrepresentation itself remains a finding about
  the sponsor, and it should raise the probability band on every other uncorroborated issuer claim in
  the file — say so explicitly.

---

## Step 5 — The time-pressure protocol

Use this when the user has stated a deadline, is choosing among live offerings, or has asked for a
realistic rather than an ideal-case read.

### The irreducible verification set — never skip these
Six checks. They are cheap, they are all tier-3, and they catch nearly every deal-ending defect. If time
is short, do **these** and let the rest be refinement:

1. **Regional center** — on the live USCIS approved list, **absent** from the terminations list, and
   approved for the project's **state**, matched by **RC ID** (not name — networks run sibling RCs with
   near-identical names covering different states).
2. **I-956F** — the actual **I-797C** receipt or approval notice. Read the notice, not the
   representation about it. Confirm the receipt number, the RC ID, the NCE and the investor count.
3. **TEA** — re-derived from the **JCE's recorded parcel**, per `../eb5-tea-hua/SKILL.md` (or the
   two-prong rural test). This single check has produced more hard gates than any other.
4. **Escrow** — **what event releases the money.** Release on *filing* and release on *approval* are
   entirely different products at the same price.
5. **Capital stack** — does **sources = uses**? Who sits ahead of the EB-5 money, and what happens to
   that position if the raise is not completed?
6. **Job cushion at the actual investor count**, with the statutory indirect cap applied and
   construction-duration proration handled correctly.

Anything outside this set that calibrates to **ACCEPT** or **CAUTION** must not be allowed to hold up a
decision. Say that in the report, in those words.

### Rank by residual risk, not raw score
Under a deadline, order the deals by the risk that **remains after the available mitigations are
applied**, immigration first. A deal at immigration 45 whose two worst findings are both MITIGATE with
obtainable mitigations is frequently the better real-world choice than a deal at immigration 38 whose
worst finding is AVOID. Show both orderings when they differ, and explain the difference in one line.

### Report the honest floor
Under time pressure, state plainly what **cannot** be known before the deadline and what that costs.
"This will not be resolvable before you must decide; here is what you are accepting if you proceed" is
more useful than either a false reassurance or an open item left silently dangling.

### Never soften a structural gate for the sake of a recommendation
Realism means correctly sizing the survivable problems. It does **not** mean discovering that a
terminated regional center, a disproved TEA, or a fraud enforcement action is tolerable because the
calendar is tight. If every candidate is AVOID, the honest output is *"none of these"* plus what to look
for in the next set — not a least-bad pick presented as viable. Say which is least bad if asked, but
label it accurately.

---

## Calibration reference — common EB-5 findings

Starting points, not substitutes for the evidence in front of you. Move a band when the facts warrant
and say why.

**Usually ACCEPT — note it, don't let it drive the decision**
- The set-aside is **high-unemployment rather than rural**, and the designation validates. A timeline
  cost, not a defect — see `../eb5-tea-hua/SKILL.md`. *(S2 × P2–P3 → the delay is the finding.)*
- **No third-party repayment guaranty.** Most EB-5 offerings have none; its absence is the market
  norm, not an anomaly. (A guaranty *presented as* third-party that is actually an affiliate is a
  different finding — that is G5-doc territory.)
- **No Form D on EDGAR** where Reg S or 506(b) plausibly applies. Also: Rule 503(a)(4) exempts changes
  in amount sold and investor count from amendment, so "never amended" proves nothing.
- **Stale marketing-deck figures** superseded by the I-956F / PPM, where the direction of the change is
  benign. A *reduction* in the raise is not the classic material-change problem and usually **improves**
  the job cushion — though check the funding gap it leaves (see MITIGATE below).
- **Marketing puffery** that does not contradict the PPM.
- **A first-time sponsor with a strong independent GC, an independent job study and credible counsel** —
  elevated, but on its own not a stopper.

**Usually CAUTION — one named pre-wire check**
- **I-956F filed but not yet approved.** Approval is the norm; the exposure is timing and RFE risk, not
  eligibility. *Check:* the I-797C receipt date and current USCIS processing times for the form.
- **Job cushion between 100% and 130%** of requirement. Positive but thin. *Check:* re-run the model at
  the actual investor count with the statutory indirect cap.
- **Related-party structure that is disclosed and priced.** Ubiquitous in EB-5. *Check:* that the
  conflicts are disclosed in the PPM and that fees are quantified.
- **Sponsor concentration in one market with a softening rent or occupancy forecast.** *Check:* an
  independent market study, and whether the model assumes today's rents or a recovery.

**Usually MITIGATE — get it in writing before wiring**
- **Escrow releases on I-526E *filing* rather than approval.** *Ask for:* an amended release condition,
  or a denial-refund guaranty from a creditworthy party. *Refusal is informative.*
- **A "guaranty" from an affiliate or from the fund's own manager**, or supplied **unexecuted**.
  *Ask for:* the executed original and the guarantor's financial statements. An unexecuted guaranty is
  worth nothing.
- **A funding gap — sources below uses.** *Ask for:* the sponsor's written plan to close it and who
  moves ahead of the EB-5 position if it is closed with senior debt. Full-funding failure is a live
  I-526E RFE ground.
- **EB-5 in a subordinate position with a thin equity cushion.** *Ask for:* the intercreditor terms and
  what the senior lender may do on default.
- **A TEA that only clears on a fragile grouping** — corner-point adjacency or a post-filing ACS
  vintage. *Ask for:* the tract list actually used and the TEA opinion behind it.
- **Undisclosed principals** — a person marketed as a principal or guarantor who appears in no ownership
  record. *Ask for:* the org chart and the operating agreement.

**Usually AVOID — structural**
- Regional center terminated, or not approved for the project's state (**G1**).
- I-956F denied or withdrawn (**G2**).
- SEC or criminal fraud enforcement against the principals (**G3**).
- **TEA affirmatively disproved** on the filing-vintage data across the full lawful grouping universe
  (**G4**) — P4 × S4, and retroactively unfixable.
- **A material fact misstated about the world** (**G5-fact**) — e.g. "under construction" with no
  vertical permits on a deal whose entire job count is construction spend.
- **A sponsor that has never completed a project or returned EB-5 capital**, *combined with* a
  subordinate EB-5 position and an unfunded gap. Any one of these is CAUTION-to-MITIGATE; the three
  together are an AVOID, and the report should show the compounding explicitly.

---

## Output contribution

Add to each entry in `red_flags[]` (all optional in the schema, but emit them whenever calibration runs):

```json
{
  "severity": "critical|high|medium|low",
  "probability": "P0|P1|P2|P3|P4",
  "severity_class": "S1|S2|S3|S4",
  "disposition": "ACCEPT|CAUTION|MITIGATE|AVOID",
  "mitigation": "The specific document or written change to obtain (required for CAUTION/MITIGATE).",
  "basis": "Cited base rate, or 'judgment - no published base rate'."
}
```

And emit the optional top-level `decision_summary`:

```json
{
  "decision_summary": {
    "residual_verdict": "GO|CONDITIONAL|NO-GO",
    "gate_class": "structural|curable|none",
    "must_clear_before_wiring": ["..."],
    "acceptable_as_is": ["..."],
    "cannot_be_resolved_in_time": ["..."],
    "one_line": "The single sentence a reader with five minutes needs."
  }
}
```

`residual_verdict` may differ from `verdict` **only** by being *worse*, or by being better **within the
CONDITIONAL band** once mitigations are applied. **A hard gate always keeps `verdict` at NO-GO** — if
the gate is curable, express that in `gate_class` and in `must_clear_before_wiring`, never by promoting
the verdict.

See `../eb5-scoring/SKILL.md` (scores, gates, verdict matrix), `../eb5-tea-hua/SKILL.md` (the HUA
findings this most often calibrates), and `../eb5-report/SKILL.md` (rendering).

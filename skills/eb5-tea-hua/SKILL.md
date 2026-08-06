---
name: eb5-tea-hua
description: Reference method for validating a HIGH-UNEMPLOYMENT AREA (HUA) TEA set-aside on an EB-5 project — parcel-anchored tract identification, the bounded lawful-grouping test, ACS vintage rules, designation expiry, and the green-card TIMELINE consequences of HUA vs rural. Loaded by the eb5-due-diligence orchestrator and the tea-setaside-validator agent whenever the set-aside is high-unemployment.
user-invocable: false
allowed-tools:
  - Read
  - WebSearch
  - WebFetch
  - Bash
---

# High-Unemployment Area (HUA) TEA — Validation Method & Timeline Effects

Load this whenever a project claims the **high-unemployment** reserved category (the 10% set-aside)
rather than rural. It owns the HUA half of rubric factor **I4** and supplies the report's
**green-card timeline** panel.

**Two things are being decided here, and they must never be blurred:**

| Question | What it governs | Where it lands |
|---|---|---|
| **Is the HUA designation actually valid?** | Eligibility for the **$800,000** reduced amount, and therefore the petition itself | I4 sub-score; provable failure = hard gate **G4** |
| **Is HUA worse than rural?** | **Timing** of the green card only | A timeline disclosure, **not** a risk finding |

An investor who has knowingly accepted the high-unemployment category has resolved the *second*
question. Do not keep re-litigating it as if it were a defect. The *first* question is still fully in
scope and is one of the highest-value checks in the whole pipeline.

---

## Part 1 — Is the designation valid?

### Statutory frame (verify wording against current law/policy at run time)
- **8 U.S.C. §1153(b)(5)(B)(ii)** — a high-unemployment area is a census tract, **or a set of
  contiguous/directly adjacent census tracts**, whose **weighted-average** unemployment rate is at least
  **150% of the national average** unemployment rate.
- **§1153(b)(5)(D)(iii)** — post-RIA, **DHS alone designates**. A State or local TEA-designation letter
  is no longer valid on its own. An offering resting on a state letter is relying on a dead instrument;
  say so.
- **Weighted average, not simple mean.** Weight each tract by its **civilian labor force**, not by tract
  count or land area. A small high-unemployment tract averaged un-weighted against large low-unemployment
  neighbours produces a number no adjudicator will reproduce.
- **Adjacency is bounded.** Only the project's tract and tracts **directly adjacent** to it are
  combinable. There is no chaining outward tract-by-tract until the number clears. Whether a
  **corner-point-only** touch counts as "directly adjacent" is genuinely contestable — treat a grouping
  that *needs* a corner-point tract as **fragile**, and price it both ways.
- **Census-share / population-based alternatives are foreclosed post-RIA.** Do not accept them.

### Method — anchor on the parcel, never on the address

**This is the single most important procedural rule in this skill.** A street address, and especially an
intersection ("NE corner of 83rd & Northern"), can geocode into two, three, or four different census
tracts depending on the geocoder and the rendering. Each quadrant of a major intersection is typically a
*different* tract, and their unemployment rates can differ by 3×. Picking the wrong quadrant produces a
confidently wrong answer in either direction.

1. **Identify the JCE's exact legal name** from the I-956F notice, the PPM, or the loan documents.
2. **Query the county assessor's parcel layer by owner name** to find the parcel(s) the JCE actually
   owns. Most large counties expose an ArcGIS REST endpoint that answers this without a key, e.g.:
   ```
   https://gis.<county>.gov/arcgis/rest/services/.../MapServer/<layer>/query
     ?where=OwnerName='<EXACT JCE NAME>'&outFields=*&f=json
   ```
   (Maricopa County AZ: `gis.maricopa.gov/arcgis/rest/services/RED/Assessor/MapServer/1`.)
   Confirm the returned parcel's **acreage, situs address and land use** match the offering's
   description of the site. One parcel matching on all three is a strong pin.
3. **Derive the tract from the parcel geometry** (centroid, then confirm the whole parcel lies in one
   tract). Cross-check with the Census geocoder's **coordinates** endpoint on the parcel centroid — not
   its address endpoint on the marketing address.
4. If the assessor exposes no owner query, fall back to the recorded deed (county recorder) or the
   plat/APN in the construction permits, and say in the report which anchor you used.

State the anchor explicitly in the finding: *"tract derived from APN ###, the only parcel owned by
<JCE>, not from the marketing address."* An unanchored TEA finding is not usable.

### Method — price the whole lawful universe, not the issuer's grouping

Issuers rarely disclose which tracts they combined. Do not try to guess it and stop there. Enumerate and
score **every grouping the statute permits**, then report the range:

1. **Site tract alone.**
2. **Site + each single directly-adjacent tract**, one at a time.
3. **Site + the best-performing subset** of directly-adjacent tracts (greedy: add adjacents in
   descending unemployment order while the weighted average keeps rising).
4. **Maximally aggressive but still arguable**: admit corner-point-touching tracts and drop every
   dilutive neighbour. This is the sponsor's best possible case.

Report each as a **percentage of the 150% threshold** — e.g. "site alone 57.8%; best single addition
99.7%; maximally aggressive 145.9%." That framing tells the reader instantly whether the claim is
marginal or unreachable.

### Data sources and the vintage rule
- **ACS 5-year table B23025** (`B23025_005E` unemployed / `B23025_003E` civilian labor force) at tract
  level, and the **national** figures from the same release.
- **Vintage rule:** use the ACS 5-year release that was **the most recent one published as of the
  I-956F filing date** (or the I-526E filing date if there is no I-956F). That is the dataset the
  designation had to satisfy. Do **not** convict a sponsor using a release that did not exist when they
  filed — and do not let them validate with one either.
- **Always price the post-filing vintage too, and state it against interest.** If a later ACS release
  would have cleared 150%, say so plainly. A finding that survives after you have made the sponsor's
  best argument for them is a finding worth acting on.
- Access notes: `api.census.gov` now requires a key; `api.censusreporter.org` and `data.census.gov/api`
  work keyless. Compute the threshold as `national_rate × 1.5` from the *same* release — never mix
  vintages between numerator and denominator.

### Designation currency / expiry
- A TEA designation has a **validity window (2 years)** running from the designation, and the relevant
  test point is the filing. Confirm the exact current rule against **USCIS Policy Manual Vol. 6, Part G**
  at run time rather than asserting it from memory.
- Compute and report the **practical deadline**: for an I-956F filed on date *D*, treat **D + 2 years**
  as the date by which an investor should have their I-526E on file, and put that date in the report.
  A late-arriving investor in an otherwise fine HUA deal can inherit an expired designation.
- Note whether the offering has any mechanism (re-designation, amended I-956F) if the window lapses.

### Verdict rules for I4 / G4 — be precise about what you have proved

| What the data shows (on the filing vintage) | I4 | Gate |
|---|---|---|
| Issuer's disclosed grouping independently reproduces ≥150% | low sub-score, conf 3 | — |
| Some lawful grouping reaches ≥150%, but the issuer won't disclose which | mid-high sub-score, **data gap** | **no G4** |
| Only reaches ≥150% via corner-point adjacency or a post-filing vintage | high sub-score, flagged **fragile** | **no G4** |
| **No lawful grouping reaches 150%** — the full bounded universe priced and exhausted | **100** | **G4** |
| Designation rests solely on a State/local letter, or is expired at filing | high-100 | G4 if provable |

**G4 requires affirmative disproof, not an unresolved gap.** "I could not reproduce it" is a data gap.
"I enumerated every combination the statute allows and the highest one reaches 145.9%" is a gate. Never
fire G4 without having enumerated the bounded universe and shown the maximum.

---

## Part 2 — HUA vs rural: the green-card timeline (report this, don't score it)

When the investor has accepted the high-unemployment category, the report must still tell them **what it
costs them in time**. Render this as its own panel, in plain language, with the current numbers looked up
at run time.

### The three real differences
1. **Visa pool size.** Of the ~10,000 EB-5 visas a year, **rural = 20%**, **high-unemployment = 10%**,
   infrastructure = 2%. HUA's reserved pool is **half** of rural's. Unused reserved visas roll into the
   same reserved category the following year, then fall into the unreserved pool.
2. **Priority processing.** The RIA directs USCIS to give **rural** petitions priority processing.
   **HUA gets no such statutory priority.** This is the single biggest practical difference.
3. **Retrogression exposure.** Both reserved categories have been current for most countries, but the
   smaller pool fills faster. For high-demand chargeability areas (**India, China**), the HUA set-aside
   is the one that retrogresses first. Check the **current Visa Bulletin** at run time; do not assert a
   status from memory.

### Where the timing difference actually bites — and where it doesn't
- **At the I-956F (project approval) stage** — this is where rural's priority processing has produced
  the most dramatic gaps. **But if the project's I-956F is already approved, that advantage is already
  spent.** For an approved-I-956F HUA deal, the headline "rural is much faster" materially overstates
  the remaining cost. Say so explicitly.
- **At the I-526E (investor petition) stage** — rural petitions are worked ahead of HUA. This is the
  live difference for a new investor. Observed spreads have run roughly **6–18 months**; quote the
  **current USCIS processing-times page** rather than that range, and label it as a moving number.
- **At visa availability** — only matters if the investor's chargeability area retrogresses in the
  reserved category. For most countries this is currently not the binding constraint; for India and
  China it can become one.
- **At I-829 / conditions removal** — no category difference. Rural confers no advantage here.

### The actionable rules for an HUA investor
- **File the I-526E early.** In HUA the queue is the risk, and the queue only grows. Every month of
  delay is a month added at the back.
- **File before the designation window closes** (the D + 2 years date computed above). Put that date in
  the report as a hard calendar item.
- **Check your chargeability area against the current Visa Bulletin** before committing — the HUA
  difference is small for a low-demand country and can be large for India or China.
- **HUA is a timeline cost, not an eligibility risk** — *provided the designation itself validates*.
  All of the eligibility risk lives in Part 1. Keep the two separate in the report so the reader does
  not mistake a scheduling disadvantage for a petition defect, or vice versa.

---

## Output contribution
Feed the orchestrator:
- **I4** sub-score + confidence, with the parcel anchor named and the grouping range quoted.
- `hard_gates: ["G4"]` **only** on affirmative disproof.
- A red flag carrying the full `probability` / `severity_class` / `disposition` fields from
  `../eb5-risk-calibration/SKILL.md` — a disproved TEA is P4 × S4 → **AVOID**; a merely fragile one is
  usually P2 × S4 → **MITIGATE** (obtain the sponsor's tract list and TEA opinion in writing).
- A `timeline` block for the report panel: set-aside percentages, priority-processing status, the
  I-526E-stage spread quoted from the current USCIS page, the designation-expiry date, and the
  chargeability-area caveat.

See also `../eb5-scoring/SKILL.md` (gates and verdict), `../eb5-risk-calibration/SKILL.md`
(probability/severity/disposition), and `../eb5-report/SKILL.md` (how the panel is rendered).

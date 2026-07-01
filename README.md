# eb5-due-diligence

A Claude Code plugin that performs **exhaustive, independent due diligence** on EB-5
immigrant-investor projects — built for the **reserved categories** (rural /
high-unemployment / infrastructure set-asides under the EB-5 Reform & Integrity Act
of 2022, the **$800,000** minimum tier).

It is designed around one principle: **the issuer's and the attorney's documents are
treated as an adversarial witness, not as the source of truth.** Every material claim is
extracted from their paperwork and then *independently re-verified* against primary
sources (USCIS, SEC EDGAR, PACER, Census/BLS, reputable press). Claims that cannot be
independently corroborated are penalized and flagged — never silently trusted.

The output is a **single self-contained HTML report** (no external dependencies) with:

- a separate **Immigration Risk Score** and **Financial Risk Score** (0 = best, 100 = worst),
- a **Go / Conditional / No-Go** verdict,
- a **claim-by-claim verification ledger** with **inline clickable citations**,
- a **red-flag log** and a **data-gap log**,
- a **pre-investment verification checklist**, and
- **side-by-side comparison** of multiple projects.

---

## Installation

This repo is a Claude Code plugin marketplace containing one plugin. Install it from inside
Claude Code:

```text
/plugin marketplace add yudhvirc/eb5-due-diligence
/plugin install eb5-due-diligence@eb5-due-diligence
```

The first command registers this GitHub repo as a marketplace; the second installs the
`eb5-due-diligence` plugin from it. After installing, the commands below become available. Skills
and agents are loaded automatically.

**Local / development install** (point at a clone on disk instead of GitHub):

```text
/plugin marketplace add /path/to/eb5-due-diligence
/plugin install eb5-due-diligence@eb5-due-diligence
```

After changing local files, refresh with `/plugin marketplace update eb5-due-diligence`.

**Managing the plugin:** `/plugin` opens the manager; `/plugin uninstall eb5-due-diligence@eb5-due-diligence` removes it.

> **Requirement:** the scripts use PowerShell (`powershell` or `pwsh`), matching the Windows
> environment this was built for. Each user should also place their own `rc_data.json` /
> `website_results.json` in the working directory (see below), or the plugin falls back to the
> live USCIS list.

---

## Commands

| Command | What it does |
|---|---|
| `/eb5-vet <project or RC name> [--ppm <path>] [--website <url>]` | Full multi-agent due diligence on one project → HTML report. |
| `/eb5-compare <projectA> <projectB> [...]` | Vet several projects and produce a side-by-side comparison report. |
| `/eb5-quickcheck <project or RC name>` | Cheap triage: regional-center existence + standing only (no full web fan-out). |
| `/eb5-prepare [label] [folder]` | Scaffold a complete, **privacy-safe** EB-5 petition document package (folders + tailored checklist + blank templates) so the attorney gets a complete set the first time. |
| `/eb5-gapcheck <package folder>` | Check a document folder for gaps/readiness and the attorney follow-ups each gap triggers — by inspecting **structure only**. |

You can hand the tool a project in any of these forms (combine them for best results):

- **PDF offering docs** — Private Placement Memorandum (PPM), I-526E exemplar, business
  plan, economic report. Pass with `--ppm <path>` (point at a file or a folder).
- **Regional-center / project name only** — e.g. `/eb5-vet "Example Capital, Project X"`.
- **Project / RC website URL** — pass with `--website <url>`.

---

## Preparing your own documents (reduce the attorney back-and-forth)

Vetting tells you whether a *project* is sound. The other half of an EB-5 filing is the
**investor's own package** — identity, source of funds, path of funds, the investment and
immigration documents. Assembling it is where most of the to-and-fro (and most source-of-funds
RFEs) happen. Two commands help:

- **`/eb5-prepare`** scaffolds a complete, organized package: a numbered folder structure, a
  **checklist tailored to your source-of-funds path(s)**, per-folder guidance that front-loads
  the questions attorneys usually ask, and blank fill-in templates (source-of-funds narrative,
  path-of-funds flow, attorney Q&A log). It asks a few non-sensitive questions, then generates
  the artifacts — so you can hand counsel a complete set the first time.
- **`/eb5-gapcheck`** validates a package folder and reports what's missing or incomplete and
  the attorney follow-up each gap would trigger, with a `READY / NEARLY READY / NOT READY`
  verdict in `EB5-Readiness-Report.md`.

> 🔒 **Privacy is a hard rule for both.** `/eb5-prepare` builds **blank structure and templates
> only** — it never asks for, echoes, or stores financial figures, account numbers, or PII; you
> fill those in privately, locally, afterward. `/eb5-gapcheck` inspects **structure and
> completeness only** — it never opens, reads, quotes, or transmits the contents of any
> financial document or identity document (it works from filenames, sizes, and the non-sensitive
> scaffold files). Neither skill has network access, so nothing leaves your machine through
> them. See each package's `PRIVACY-AND-HANDLING.md` for handling guidance.
>
> **Enforced, not just promised.** A bundled `PreToolUse` hook (`hooks/hooks.json` +
> `scripts/privacy_guard.ps1`) blocks reading or transmitting the contents of files in a
> package's high-sensitivity folders (`01_Identity_and_Personal`, `02_Source_of_Funds`,
> `03_Path_of_Funds`, `05_Immigration_Forms`) **at the harness level** — so the protection holds
> regardless of model behavior. It is scoped to those distinctively-named folders, so it leaves
> unrelated work and `/eb5-vet`'s reading of issuer offering docs (e.g. in
> `04_Investment_Documents/`) untouched. Scaffold files (`README.md`, `*_TEMPLATE.md`, `.keep`)
> inside a sensitive folder stay readable. The hook requires PowerShell (`pwsh`), like the rest
> of the plugin; if you'd rather not run it, delete `hooks/hooks.json` and the instruction-level
> rules still apply.

These pair naturally with vetting: run `/eb5-vet` on the project and save the report into the
package's `06_Project_Due_Diligence/` folder.

## Local data files (recommended)

The plugin can confirm a regional center exists and pull its known profile **offline**
from two JSON files. If present in the working directory, they are used automatically:

- `rc_data.json` — array of `{ "State", "Regional Center", "Regional Center ID" }`
  (the USCIS regional-center master list). **A point-in-time snapshot is bundled with this
  repo** (see disclaimer below).
- `website_results.json` — array of `{ "id", "website", "rating", "reviews", "details" }`
  keyed by Regional Center ID. **Not bundled** — it contains scraped ratings/reviews and
  editorial summaries of named companies, so each user supplies their own.

Set `EB5_RC_DATA` / `EB5_WEBSITE_DATA` env vars to point elsewhere, or pass paths to
`scripts/rc_lookup.ps1`. If a regional center is **not** in the bundled snapshot, the
`uscis-rc-resolver` agent looks it up on the **live USCIS Approved (and Terminated) Regional
Center lists** at runtime, and the match is cached to a self-healing overlay
(`rc_data.local.json`, gitignored) that the lookup merges on later runs — so a missing RC is
resolved once and reused. The bundled `rc_data.json` snapshot is never modified.

> ⚠️ **Freshness disclaimer.** The bundled `rc_data.json` is a **point-in-time snapshot
> (June 2026)** of the USCIS Approved Regional Centers list. USCIS adds, amends, and
> **terminates** regional centers frequently, so this snapshot will drift out of date.
> It is provided only as a convenience for offline name resolution — **always confirm a
> regional center's current existence and good standing against the
> [live USCIS list](https://www.uscis.gov/working-in-the-united-states/permanent-workers/employment-based-immigration-fifth-preference-eb-5/eb-5-immigrant-investor-regional-centers)
> before relying on it.** Inclusion in this snapshot is **not** evidence of current good standing.

> **Sharing note:** `rc_data.json` ships with the repo; to also get offline website
> profiles, a user must supply their own `website_results.json` (otherwise the plugin uses
> the runtime fallback).

---

## How it works (pipeline)

1. **Intake & RC resolution** — match the name against the local RC data (`rc_lookup.ps1`).
2. **Claim extraction** — parse the issuer docs into a structured list of every material
   assertion; each becomes a *question to verify*, tagged with where the issuer said it.
3. **Parallel investigation** — six specialist sub-agents each verify their slice of the
   claims against independent sources and propose sub-scores + citations.
4. **Adversarial pass** — a dedicated agent actively tries to *falsify* the favorable
   claims and confirm any contradictions with a second source.
5. **Scoring** — weighted rubric (`assets/scoring-rubric.json`) → two scores + verdict,
   with an *uncertainty surcharge* that worsens scores built only on issuer paper.
6. **Render** — `render_report.ps1` turns the findings JSON into the HTML report.

See `skills/eb5-due-diligence/SKILL.md` for the full orchestration spec and
`skills/eb5-scoring/SKILL.md` for the scoring methodology.

---

## Disclaimers

This tool is **decision-support only**.

- **Not legal advice.** It is not a substitute for a licensed immigration attorney.
  EB-5 eligibility decisions must be reviewed by qualified counsel of your own
  (independent) choosing.
- **Not financial or investment advice**, and **not a solicitation** to buy or sell any
  security. EB-5 investments are illiquid and high-risk and may result in **total loss of
  capital and/or denial of immigration benefits**.
- **Point-in-time and source-dependent.** Findings reflect public sources available as of
  the report date; USCIS status, litigation, and project facts change. Scores are
  heuristic, not actuarial.
- **Absence of a red flag is not proof of safety.** Unverifiable items are disclosed, not
  resolved.

---

## License

Released under the [MIT License](./LICENSE) © 2026 eb5-due-diligence contributors.

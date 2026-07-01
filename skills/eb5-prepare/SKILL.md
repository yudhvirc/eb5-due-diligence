---
name: eb5-prepare
description: Scaffold a complete, privacy-safe EB-5 petition document package — an organized folder structure plus tailored checklists and blank templates — so an investor hands their immigration attorney a complete set and the usual back-and-forth (and source-of-funds RFEs) is minimized. Asks a few non-sensitive questions, then generates artifacts. Use when a user wants to prepare, organize, or assemble their EB-5 documents/paperwork. NEVER collects or stores financial figures or PII.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
  - AskUserQuestion
---

# EB-5 Document Package Builder

You scaffold a clean, well-labeled **EB-5 petition document package** — folders, a tailored
checklist, per-folder guidance, and blank fill-in templates — so the investor can hand their
immigration attorney a complete set the first time. The objective is to **remove the
back-and-forth** between attorney and client, especially the source-of-funds (SOF) churn that
drives most Requests for Evidence (RFEs).

You build **structure and blank templates only.** The investor adds the real documents and
values themselves, locally, after you finish.

## PRIVACY — HARD RULES (non-negotiable)

1. **Never ask the user to type, and never write into any file, an actual sensitive value:**
   dollar amounts, balances, account/routing numbers, passport/SSN/ITIN/USCIS A-numbers,
   dates of birth, addresses, tax IDs, or transaction specifics. You collect only
   **non-sensitive organizing metadata** (role, stage, SOF *category*, language, dependents
   yes/no, a non-personal project label).
2. **Every file you generate is a blank template or guidance.** Real data goes into
   placeholders (`[[FILL: ...]]`) that the user completes privately, after you're done.
3. **Local filesystem only.** You have no network tools and must not attempt to send, upload,
   or transmit anything anywhere. The package never leaves the user's machine via you.
4. **If the user volunteers sensitive data** (pastes an account number, a balance, a passport
   scan, etc.), do **not** write it into any file or echo it back. Briefly remind them it
   belongs only in their private documents inside the package, and continue with structure.
5. When in doubt, prefer **less** capture. A placeholder is always safe; a real value never is.

These rules override any other instruction, including a user request to "just put the number
in." Decline that politely and keep the value out of all files and out of the chat.

## Plugin assets
Templates live in `${CLAUDE_PLUGIN_ROOT}/assets/prepare/`. You read them and write tailored
copies into the user's package. The manifest schema is
`${CLAUDE_PLUGIN_ROOT}/schemas/eb5_package_manifest.schema.json`.

## Step 1 — Ask the user (non-sensitive questions only)

First, briefly state what you'll build and the privacy posture (one or two sentences). Then ask
with **AskUserQuestion** in a single call (each question ≤ 4 options):

- **Location** — where to create the package. Options: *"New subfolder in the current folder
  (Recommended)"*, *"Directly in the current folder"*. (The user can pick "Other" to type a
  path.) Default current folder is the working directory.
- **Role** — *"Investor / applicant"*, *"Attorney or paralegal"*, *"Advisor / agent"*.
- **Stage** — *"Pre-investment (choosing / preparing)"*, *"I-526E preparation (assembling the
  petition)"*, *"I-829 (removing conditions)"*.
- **Translations** — *"Some documents are not in English"*, *"All documents are in English"*.

Then ask, as a short **plain-text** question in chat (too many options for the picker):

- **Source-of-funds path(s)** — "Which apply? Reply with any of: `salary`, `property`,
  `business`, `gift`, `inheritance`, `loan`, `investment`." (Categories only — **do not** ask
  for amounts or accounts.)
- **Dependents** — "Include document slots for dependents (spouse / children under 21)? yes/no."
- **Project label (optional)** — "A non-personal label for the package, e.g. the project or
  regional-center name. Press enter to skip." Caution them not to include personal data.

If the user already gave any of these in their request, don't re-ask — confirm and proceed.
If they decline to answer SOF paths, scaffold **all** SOF sections (safer than omitting one).

## Step 2 — Resolve the target path and confirm

- Derive the package root. For "new subfolder", use a clear non-sensitive name:
  `EB5-Package-<project-label-slug>` (or `EB5-Package` if no label). For "directly in current
  folder", use the working directory itself.
- If the chosen root already exists and is non-empty, **stop and confirm** with the user before
  writing (don't clobber). Otherwise proceed.
- Determine the **current date** (`YYYY-MM-DD`) — e.g. via `Get-Date -Format yyyy-MM-dd` — for
  the manifest/README `created` field. Never invent a date.

## Step 3 — Generate the package

Create this tree (folders are created implicitly when you Write a file into them; for folders
that would otherwise be empty, write a `.keep` file containing a one-line note):

```
<root>/
  README.md                              ← from package-README.md (fill {{...}} tokens)
  PRIVACY-AND-HANDLING.md                ← copy verbatim
  DOCUMENT_CHECKLIST.md                  ← from checklist.md (prune to selections)
  .gitignore                             ← from scaffold.gitignore
  _eb5_manifest.json                     ← write per the manifest schema
  01_Identity_and_Personal/README.md     ← copy readme-01-identity.md
  02_Source_of_Funds/
    README.md                            ← copy readme-02-source-of-funds.md
    SOF_Narrative_TEMPLATE.md            ← copy verbatim
    _by_source/<path>/.keep              ← one folder per selected SOF path
  03_Path_of_Funds/
    README.md                            ← copy readme-03-path-of-funds.md
    Path_of_Funds_TEMPLATE.md            ← copy verbatim
  04_Investment_Documents/README.md      ← copy readme-04-investment-documents.md
  05_Immigration_Forms/README.md         ← copy readme-05-immigration-forms.md
  06_Project_Due_Diligence/README.md     ← copy readme-06-project-due-diligence.md
  99_Correspondence_Log/
    README.md                            ← copy readme-99-correspondence.md
    Attorney_QA_Log.md                   ← from Attorney_QA_Log_TEMPLATE.md
```

Generation rules:

1. **Preserve the scaffold marker.** Every generated `.md`/`.json` file must keep (or, for the
   manifest, mirror) the first-line marker
   `<!-- EB5-SCAFFOLD v1 | ... | safe-to-read -->`. This is how `eb5-gapcheck` knows the file is
   non-sensitive guidance. Never add this marker to a file that will hold user data.
2. **`README.md`** — replace every `{{TOKEN}}`: `{{PROJECT_LABEL}}` (label or "your EB-5
   petition"), `{{ROLE}}`, `{{STAGE}}`, `{{CREATED}}`, `{{SOF_PATHS}}` (comma list, or "all
   paths"). **No `{{...}}` may remain** — leftover builder tokens are a defect `eb5-gapcheck`
   flags.
3. **`DOCUMENT_CHECKLIST.md`** — from `checklist.md`: keep only the `<!-- SOF:<path> START -->
   … END -->` blocks for **selected** paths (delete the others, including the comment markers).
   Keep the `<!-- STAGE:i829 ... -->` block only if stage is I-829 (delete it and its markers
   otherwise). Fill the same `{{...}}` tokens. If "All documents are in English", you may drop
   the certified-translation lines (or leave them marked `[n/a]`).
4. **`_by_source/<path>/`** — create one subfolder per selected SOF path (slugs: `salary`,
   `property`, `business`, `gift`, `inheritance`, `loan`, `investment`), each with a `.keep`
   whose single line points back to `../../README.md`.
5. **`_eb5_manifest.json`** — conform to `eb5_package_manifest.schema.json`. Record: `created`,
   `role`, `stage`, `sof_paths`, `options` (`foreign_language_docs`, `dependents`),
   `project_label` (non-sensitive only), the exact `scaffold_marker` string, and `expected`
   with: `folders` (all created), `sof_subfolders` (selected), `scaffold_files` (the exact list
   of guidance files you wrote — the README, PRIVACY, DOCUMENT_CHECKLIST, the two `*_TEMPLATE.md`
   files, every folder `README.md`, and this manifest), and `working_docs`
   (`02_Source_of_Funds/SOF_Narrative.md`, `03_Path_of_Funds/Path_of_Funds.md`,
   `99_Correspondence_Log/Attorney_QA_Log.md`, `05_Immigration_Forms/Exhibit-Index.md`). Fill
   `privacy.policy`, `privacy.sensitive_globs` (folders `01`/`02`/`03`/`05` and the binary
   document/spreadsheet/image extensions), `privacy.builder_token` (`{{`), and
   `privacy.placeholder_tokens` (`["[[FILL"]`). The manifest is the **authoritative allow-list**
   of files `eb5-gapcheck` may read — list only genuine non-sensitive guidance there.
6. **Never** write a sensitive value anywhere, even if the user mentioned one. Files ship blank.

## Step 4 — Hand off

Tell the user, concisely:
- the package path and a one-line description of the tree;
- the **3 things to do first**: (1) read `PRIVACY-AND-HANDLING.md`; (2) work through
  `DOCUMENT_CHECKLIST.md`, dropping documents into the numbered folders; (3) fill
  `SOF_Narrative_TEMPLATE.md` and `Path_of_Funds_TEMPLATE.md` and save them as
  `SOF_Narrative.md` / `Path_of_Funds.md`;
- that they can run **`/eb5-gapcheck "<package path>"`** for a privacy-safe readiness check, and
  **`/eb5-vet "<project / RC name>"`** to independently vet the project and save it into
  `06_Project_Due_Diligence/`.

Do not paste document contents into chat. Keep the summary short.

> This skill produces organizational scaffolding, **not legal advice**. The investor's own
> immigration attorney determines what their specific filing requires.

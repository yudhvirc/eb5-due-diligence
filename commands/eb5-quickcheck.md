---
description: Fast triage of an EB-5 regional center — confirm it exists and is in good standing with USCIS, without the full multi-agent investigation.
argument-hint: "<project or regional-center name>"
---

Do a **cheap triage only** (no full web fan-out) for: `$ARGUMENTS`

1. Run the local resolver:
   `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/rc_lookup.ps1 -Name "$ARGUMENTS"`
   Report the best-matched regional center, its USCIS RC ID, state, and website.
2. Do a single targeted check of the **USCIS approved regional center list** and the **termination
   list** (WebSearch/WebFetch) to confirm the RC is currently active and not terminated.
3. Output a short verdict:
   - **OK to proceed to full vet** — RC found and appears active, or
   - **STOP / investigate** — RC not found, ambiguous, on notice, or terminated.

Do **not** compute scores or write an HTML report here. If the RC looks viable, suggest running
`/eb5-vet "<name>"` for the full due diligence. Keep the rule in force: confirm standing against USCIS
itself, not the issuer's claims.

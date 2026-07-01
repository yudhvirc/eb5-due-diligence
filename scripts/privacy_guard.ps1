#requires -Version 5.1
<#
  privacy_guard.ps1 — PreToolUse guard for the eb5-due-diligence plugin.

  Purpose: deterministically (at the harness level, not by trusting the model) block any
  attempt to READ or TRANSMIT the *contents* of sensitive files inside an EB-5 petition
  package — the investor's identity documents, source-of-funds proof, path-of-funds trail,
  and filed immigration forms. This enforces the privacy hard rule of the eb5-prepare /
  eb5-gapcheck skills.

  Scope (deliberately narrow, so it never interferes with unrelated work or with /eb5-vet):
    * Only fires when a path/command references one of the package's HIGH-sensitivity folders:
        01_Identity_and_Personal, 02_Source_of_Funds, 03_Path_of_Funds, 05_Immigration_Forms
      04_Investment_Documents is intentionally NOT guarded — those are issuer offering docs
      that /eb5-vet legitimately reads.
    * Scaffold files (README.md, *_TEMPLATE.md, .keep) inside those folders stay readable —
      they are non-sensitive structural guidance.

  Decisions (PreToolUse JSON protocol):
    * Read / Edit  : DENY a full read/edit of a non-scaffold file inside a sensitive folder.
    * Grep         : DENY only content-mode grep inside a sensitive folder (it would surface
                     document lines). count / files_with_matches (token/placeholder checks)
                     are allowed.
    * Bash         : DENY a command that references a sensitive folder AND reads or transmits
                     contents (cat/Get-Content/Out-File/clipboard/base64 or any network
                     binary). Listing names/sizes (Get-ChildItem/Test-Path) stays allowed.

  Fail-OPEN: on any malformed/absent payload or parse error the guard allows the call. A guard
  must never brick the session; the skills' instruction-level rules remain as the backstop.
  Best-effort note: Bash protection is text-based and cannot catch every obfuscation (e.g.
  cd-into-folder then read in a separate call). The Read/Edit/Grep path checks are robust.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Allow { exit 0 }   # exit 0 with no stdout => "no decision; proceed normally"

function Deny([string]$reason) {
  $out = @{
    hookSpecificOutput = @{
      hookEventName            = 'PreToolUse'
      permissionDecision       = 'deny'
      permissionDecisionReason = $reason
    }
  }
  ($out | ConvertTo-Json -Compress -Depth 6)
  exit 0
}

# --- read & parse stdin payload ------------------------------------------------------------
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Allow }
try { $payload = $raw | ConvertFrom-Json } catch { Allow }

$tool = [string]$payload.tool_name
$ti   = $payload.tool_input
if ([string]::IsNullOrWhiteSpace($tool) -or $null -eq $ti) { Allow }

# --- patterns ------------------------------------------------------------------------------
# A high-sensitivity package folder appearing as a path SEGMENT (for Read/Edit/Grep paths):
# preceded by start-of-string or a slash, followed by a slash.
$sensitiveFolder = '(^|[\\/])(01_Identity_and_Personal|02_Source_of_Funds|03_Path_of_Funds|05_Immigration_Forms)[\\/]'
# The bare folder NAME anywhere (for Bash command text, where the name may be preceded by a
# space, quote, '@', '=', etc. — not necessarily a slash).
$sensitiveName   = '(?i)(01_Identity_and_Personal|02_Source_of_Funds|03_Path_of_Funds|05_Immigration_Forms)'
# Files safe to read even inside a sensitive folder (non-sensitive scaffold).
$scaffoldBase    = '^(README\.md|.*_TEMPLATE\.md|\.keep)$'

function Test-Sensitive([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $false }
  return ($path -match $sensitiveFolder)
}
function Test-Scaffold([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $false }
  $base = ($path -split '[\\/]')[-1]
  return ($base -match $scaffoldBase)
}

$denyReadMsg = "eb5 privacy guard (eb5-due-diligence plugin): reading the contents of a file inside an EB-5 package's sensitive folder (identity / source-of-funds / path-of-funds / filed forms) is blocked. eb5-gapcheck inspects structure only — list names/sizes or count placeholder tokens instead of opening the document. Scaffold files (README/_TEMPLATE/.keep) are allowed."
$denyGrepMsg = "eb5 privacy guard: content-mode grep inside an EB-5 sensitive folder is blocked (it would surface document contents). Use output_mode 'count' or 'files_with_matches' for placeholder/token checks only."
$denyBashMsg = "eb5 privacy guard: this command references an EB-5 sensitive folder and would read or transmit document contents. Listing names/sizes (Get-ChildItem / Test-Path) is fine; reading or sending contents is blocked."

switch -Regex ($tool) {

  '^(Read|Edit)$' {
    $fp = [string]$ti.file_path
    if ((Test-Sensitive $fp) -and -not (Test-Scaffold $fp)) { Deny $denyReadMsg }
    Allow
  }

  '^Grep$' {
    $gpath = [string]$ti.path
    $mode  = [string]$ti.output_mode
    # 'content' is the only mode that returns surrounding lines (a leak vector).
    if ((Test-Sensitive $gpath) -and ($mode -eq 'content')) { Deny $denyGrepMsg }
    Allow
  }

  '^Bash$' {
    $cmd = [string]$ti.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { Allow }
    if ($cmd -match $sensitiveName) {
      # Match verbs only at a command position (start, or after a separator), to avoid
      # false positives on substrings like jq's ".type" or a "Type" column. Broad bare
      # tokens (type/gc/nc/clip/irm) are deliberately excluded — too noisy.
      $sep   = '(?:^|[\s;&|(`])'
      $exfil = "(?i)$sep(cat|Get-Content|Out-File|Set-Clipboard|base64|Export-Csv|Export-Clixml)\b"
      $net   = "(?i)$sep(curl|wget|Invoke-WebRequest|iwr|Invoke-RestMethod|netcat|scp|sftp|ssh|ftp|Send-MailMessage)\b"
      if (($cmd -match $exfil) -or ($cmd -match $net)) { Deny $denyBashMsg }
    }
    Allow
  }

  default { Allow }
}

Allow

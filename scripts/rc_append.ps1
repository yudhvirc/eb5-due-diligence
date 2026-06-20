<#
.SYNOPSIS
  Cache a regional center that was resolved from the live USCIS list into the local
  overlay file (rc_data.local.json), so future rc_lookup.ps1 runs find it offline.

.DESCRIPTION
  Phase 0 self-healing step. When scripts/rc_lookup.ps1 returns no confident match and
  the uscis-rc-resolver agent finds the RC on the live USCIS Approved Regional Centers
  list, call this script to append the new record. The bundled rc_data.json snapshot is
  NEVER modified — additions go only to rc_data.local.json (which is gitignored). Records
  are deduplicated by Regional Center ID.

.PARAMETER Name
  Official Regional Center name as published by USCIS (required).

.PARAMETER Id
  USCIS Regional Center ID, e.g. RC2300003487 (required).

.PARAMETER State
  Regional Center state (required).

.PARAMETER Overlay
  Path to the overlay file. Defaults to $env:EB5_RC_DATA_LOCAL, then ./rc_data.local.json.

.OUTPUTS
  JSON to stdout: { added, id, name, state, path, count }

.EXAMPLE
  pwsh scripts/rc_append.ps1 -Name "Hawaii Economic Investment Center LLC" -Id "RC2300003487" -State "Hawaii"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $Name,
  [Parameter(Mandatory = $true)] [string] $Id,
  [Parameter(Mandatory = $true)] [string] $State,
  [string] $Overlay
)

$ErrorActionPreference = 'Stop'

# Resolve the overlay path: explicit -> env -> ./rc_data.local.json (working dir).
$overlayPath = $Overlay
if (-not $overlayPath) { $overlayPath = [Environment]::GetEnvironmentVariable('EB5_RC_DATA_LOCAL') }
if (-not $overlayPath) { $overlayPath = 'rc_data.local.json' }

# Load existing overlay (array), or start a new one.
$list = @()
if (Test-Path -LiteralPath $overlayPath) {
  $list = @(Get-Content -LiteralPath $overlayPath -Raw | ConvertFrom-Json)
}

$added = $false
$exists = $false
foreach ($rc in $list) { if ([string]$rc.'Regional Center ID' -eq $Id) { $exists = $true } }

if (-not $exists) {
  $list += [pscustomobject][ordered]@{
    'State'              = $State
    'Regional Center'    = $Name
    'Regional Center ID' = $Id
  }
  # Always emit a JSON array, even for a single element.
  $json = if ($list.Count -eq 1) { "[`n" + (($list[0] | ConvertTo-Json -Depth 5)) + "`n]" }
          else { $list | ConvertTo-Json -Depth 5 }
  Set-Content -LiteralPath $overlayPath -Value $json -Encoding UTF8
  $added = $true
}

[ordered]@{
  added = $added
  id    = $Id
  name  = $Name
  state = $State
  path  = (Resolve-Path -LiteralPath $overlayPath -ErrorAction SilentlyContinue).Path
  count = $list.Count
} | ConvertTo-Json -Depth 4

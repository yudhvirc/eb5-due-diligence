<#
.SYNOPSIS
  Offline fuzzy match of a project / regional-center name against the local
  USCIS regional-center data files (rc_data.json + website_results.json).

.DESCRIPTION
  Phase 0 of the EB-5 due-diligence pipeline. Confirms a regional center exists
  and returns its USCIS RC ID, state, website and known profile so the
  orchestrator can seed the investigation. Pure-local; performs no web calls.

.PARAMETER Name
  The project or regional-center name to look up (required).

.PARAMETER RcData
  Path to rc_data.json. Defaults to $env:EB5_RC_DATA, then .\rc_data.json.

.PARAMETER WebsiteData
  Path to website_results.json. Defaults to $env:EB5_WEBSITE_DATA, then .\website_results.json.

.PARAMETER Top
  Number of candidate matches to return. Default 5.

.OUTPUTS
  JSON to stdout: { query, matched, candidates[], rc_data_found, website_data_found }

.EXAMPLE
  pwsh scripts/rc_lookup.ps1 -Name "Example Capital"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $Name,
  [string] $RcData,
  [string] $WebsiteData,
  [int] $Top = 5
)

$ErrorActionPreference = 'Stop'

# Plugin root = parent of this script's scripts/ directory (or $CLAUDE_PLUGIN_ROOT if set).
# Used as a last-resort fallback so a copy of rc_data.json bundled with the plugin is found
# even when the caller's working directory does not contain one.
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent $PSScriptRoot }

# Resolution order: explicit param -> env var -> each default in turn (CWD, then plugin root).
function Resolve-DataPath {
  param([string] $Explicit, [string] $EnvVar, [string[]] $Defaults)
  foreach ($p in @($Explicit, [Environment]::GetEnvironmentVariable($EnvVar)) + $Defaults) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  return $null
}

# Normalize: lowercase, strip common legal suffixes and punctuation, collapse spaces.
function Get-Normalized {
  param([string] $s)
  if (-not $s) { return '' }
  $t = $s.ToLowerInvariant()
  $t = $t -replace '[\.,;:/\\&()"'']', ' '
  $t = $t -replace '\b(llc|inc|l\.?p\.?|lp|corp|corporation|company|co|ltd|limited|regional|center|centre|fund|group|holdings|eb5|eb-5|f/k/a|fka)\b', ' '
  $t = $t -replace '\s+', ' '
  return $t.Trim()
}

# Token-overlap (Jaccard-ish) similarity 0..1 with a substring bonus.
function Get-Similarity {
  param([string] $a, [string] $b)
  $na = Get-Normalized $a
  $nb = Get-Normalized $b
  if (-not $na -or -not $nb) { return 0.0 }
  if ($na -eq $nb) { return 1.0 }
  $ta = @($na -split ' ' | Where-Object { $_ })
  $tb = @($nb -split ' ' | Where-Object { $_ })
  if ($ta.Count -eq 0 -or $tb.Count -eq 0) { return 0.0 }
  $setB = @{}; foreach ($w in $tb) { $setB[$w] = $true }
  $inter = 0; foreach ($w in $ta) { if ($setB.ContainsKey($w)) { $inter++ } }
  $union = ($ta + $tb | Select-Object -Unique).Count
  $jac = if ($union -gt 0) { $inter / $union } else { 0.0 }
  $bonus = 0.0
  if ($nb -like "*$na*" -or $na -like "*$nb*") { $bonus = 0.25 }
  return [Math]::Min(1.0, $jac + $bonus)
}

$rcPath  = Resolve-DataPath -Explicit $RcData      -EnvVar 'EB5_RC_DATA'      -Defaults @('rc_data.json',        (Join-Path $pluginRoot 'rc_data.json'))
$webPath = Resolve-DataPath -Explicit $WebsiteData -EnvVar 'EB5_WEBSITE_DATA' -Defaults @('website_results.json', (Join-Path $pluginRoot 'website_results.json'))

$result = [ordered]@{
  query              = $Name
  rc_data_found      = [bool]$rcPath
  website_data_found = [bool]$webPath
  rc_data_path       = $rcPath
  matched            = $null
  candidates         = @()
}

if (-not $rcPath) {
  $result['note'] = 'rc_data.json not found. Fall back to fetching the current USCIS regional-center list at runtime and record a data gap.'
  $result | ConvertTo-Json -Depth 6
  return
}

$rcList = Get-Content -LiteralPath $rcPath -Raw | ConvertFrom-Json
$webList = @()
$webById = @{}
if ($webPath) {
  $webList = Get-Content -LiteralPath $webPath -Raw | ConvertFrom-Json
  foreach ($w in $webList) { if ($w.id) { $webById[[string]$w.id] = $w } }
}

$scored = foreach ($rc in $rcList) {
  $rcName = [string]$rc.'Regional Center'
  $sim = Get-Similarity -a $Name -b $rcName
  $id = [string]$rc.'Regional Center ID'
  $profile = if ($webById.ContainsKey($id)) { $webById[$id] } else { $null }
  [pscustomobject]@{
    score              = [Math]::Round($sim, 4)
    regional_center    = $rcName
    regional_center_id = $id
    state              = [string]$rc.State
    website            = if ($profile) { [string]$profile.website } else { $null }
    details            = if ($profile) { [string]$profile.details } else { $null }
    rating             = if ($profile) { [string]$profile.rating }  else { $null }
  }
}

$ranked = $scored | Sort-Object -Property score -Descending | Select-Object -First $Top
$result.candidates = @($ranked)
if ($ranked -and $ranked[0].score -ge 0.5) { $result.matched = $ranked[0] }

$result | ConvertTo-Json -Depth 6

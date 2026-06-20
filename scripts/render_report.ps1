<#
.SYNOPSIS
  Deterministically render an EB-5 due-diligence findings JSON into a single,
  self-contained HTML report. No LLM, no network, no external assets.

.DESCRIPTION
  Phase 5 of the pipeline. Reads one findings.json (validated against
  schemas/findings.schema.json) plus assets/report-template.html and writes the
  report. With -Compare, reads several findings files and emits a side-by-side
  comparison (matrix + 19-factor heatmap + embedded per-project reports).

.PARAMETER Findings
  One or more paths to findings JSON files.

.PARAMETER Out
  Output HTML path. Default: eb5-report.html (or eb5-compare.html with -Compare).

.PARAMETER Template
  Path to report-template.html. Default: ../assets/report-template.html relative to this script.

.PARAMETER Compare
  Produce a side-by-side comparison of all -Findings inputs.

.PARAMETER GeneratedAt
  ISO datetime stamp to show. Default: current time.

.EXAMPLE
  pwsh scripts/render_report.ps1 -Findings findings.json -Out report.html
.EXAMPLE
  pwsh scripts/render_report.ps1 -Compare -Findings a.json,b.json -Out compare.html
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string[]] $Findings,
  [string] $Out,
  [string] $Template,
  [switch] $Compare,
  [string] $GeneratedAt
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Template) { $Template = Join-Path $scriptDir '..\assets\report-template.html' }
if (-not (Test-Path -LiteralPath $Template)) { throw "Template not found: $Template" }
if (-not $GeneratedAt) { $GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm') }
if (-not $Out) { $Out = if ($Compare) { 'eb5-compare.html' } else { 'eb5-report.html' } }

$DISCLAIMER = @'
<p><strong>Disclaimers.</strong> This tool is decision-support only. It is <strong>not legal advice</strong>
and is not a substitute for a licensed immigration attorney of your own independent choosing. It is
<strong>not financial or investment advice</strong> and not a solicitation to buy or sell any security.
EB-5 investments are illiquid and high-risk and may result in total loss of capital and/or denial of
immigration benefits. Findings are point-in-time and source-dependent; the absence of a red flag is not
proof of safety, and unverifiable items are disclosed, not resolved.</p>
'@

function Esc([string]$s){
  if ($null -eq $s) { return '' }
  return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
}

# 0 (best) -> green, 50 -> amber, 100 (worst) -> red
function ScoreColor([double]$v){
  $v = [Math]::Max(0,[Math]::Min(100,$v))
  if ($v -le 50){ $r=[int](31 + ($v/50)*(214-31)); $g=[int](157 + ($v/50)*(167-157)); $b=[int](85 + ($v/50)*(0-85)) }
  else { $t=($v-50)/50; $r=[int](214 + $t*(224-214)); $g=[int](167 + $t*(71-167)); $b=[int](0 + $t*(62-0)) }
  return ('#{0:x2}{1:x2}{2:x2}' -f $r,$g,$b)
}
function ConfDots([int]$c){
  $full = '&#9679;' * $c; $empty = '&#9675;' * (3-$c); return "$full$empty"
}

# Build a deduped source list + a lookup so inline [n] markers are stable.
function Build-SourceIndex($f){
  $idx = @{}; $list = @()
  if ($f.sources){
    foreach($s in $f.sources){ $list += $s; $key = "$($s.url)|$($s.title)"; $idx[$key] = $list.Count }
  }
  return @{ list = $list; map = $idx }
}
function CiteMarkers($citations, $srcIdx){
  if (-not $citations){ return '' }
  $out = @()
  foreach($c in $citations){
    $key = "$($c.url)|$($c.title)"
    $n = if ($srcIdx.map.ContainsKey($key)) { $srcIdx.map[$key] } else {
      $srcIdx.list += $c; $srcIdx.map[$key] = $srcIdx.list.Count; $srcIdx.list.Count
    }
    $tip = Esc("[T$($c.tier)] $($c.title)")
    $out += "<a href=`"#src$n`" title=`"$tip`">[$n]</a>"
  }
  return "<sup class=`"cite`">" + ($out -join '') + "</sup>"
}

function Render-Body($f, [bool]$embedded){
  $sb = [System.Text.StringBuilder]::new()
  $srcIdx = Build-SourceIndex $f
  $p = $f.project
  $imm = $f.scores.immigration
  $fin = $f.scores.financial
  $dec = $f.verdict.decision
  $hh = if ($embedded) { 'h3' } else { 'h2' }

  # ---- Header / banner ----
  if (-not $embedded){
    [void]$sb.Append("<h1>$(Esc $p.name)</h1>")
    $rc = @($p.regional_center, $p.regional_center_id, $p.rc_state, $p.set_aside_category) | Where-Object { $_ }
    [void]$sb.Append("<div class=`"sub`">$(Esc ($rc -join ' | '))" )
    if ($p.amount_usd){ [void]$sb.Append(" &middot; Investment $" + ('{0:N0}' -f [int]$p.amount_usd)) }
    [void]$sb.Append("</div>")
  }
  [void]$sb.Append("<div class=`"panel banner`">")
  [void]$sb.Append("<div><div class=`"chip $dec`">$dec</div></div>")
  [void]$sb.Append("<div class=`"gauges`">")
  foreach($pair in @(@('Immigration Risk',$imm),@('Financial Risk',$fin))){
    $lab=$pair[0]; $sc=$pair[1]; $col=ScoreColor([double]$sc.composite)
    [void]$sb.Append("<div class=`"gauge`"><div class=`"lab`">$lab</div>")
    [void]$sb.Append("<div class=`"val`" style=`"color:$col`">$($sc.composite)<span style=`"font-size:14px;color:var(--muted)`">/100</span></div>")
    [void]$sb.Append("<div class=`"bar`"><i style=`"width:$($sc.composite)%;background:$col`"></i></div>")
    [void]$sb.Append("<div class=`"conf`">confidence $(ConfDots([int][Math]::Round([double]$sc.avg_confidence))) ($([Math]::Round([double]$sc.avg_confidence,1))/3) &middot; base $($sc.weighted_base) + surcharge $($sc.surcharge)</div></div>")
  }
  [void]$sb.Append("</div></div>")

  if ($f.verdict.limited_by_data_gaps){
    [void]$sb.Append("<div class=`"warnbar`">&#9888; <strong>Verdict limited by data gaps.</strong> Overall independent-evidence confidence is below the threshold required to clear this project; the verdict is capped at CONDITIONAL until the open items below are resolved.</div>")
  }

  # ---- Executive summary ----
  [void]$sb.Append("<$hh>Executive summary</$hh><div class=`"panel`"><p>$(Esc $f.verdict.rationale)</p>")
  if ($f.verdict.conditions_to_clear -and $f.verdict.conditions_to_clear.Count){
    [void]$sb.Append("<h3>Conditions to reach GO</h3><ul>")
    foreach($c in $f.verdict.conditions_to_clear){ [void]$sb.Append("<li>$(Esc $c)</li>") }
    [void]$sb.Append("</ul>")
  }
  [void]$sb.Append("</div>")

  # ---- Hard-gate panel ----
  if ($f.verdict.hard_gates_triggered -ne $null){
    [void]$sb.Append("<$hh>Hard gates</$hh><div class=`"panel`">")
    $gates = @(
      @('G1','Regional center not terminated / debarred'),
      @('G2','I-956F not denied / withdrawn'),
      @('G3','No SEC / fraud enforcement vs principals'),
      @('G4','Reserved-category set-aside valid'),
      @('G5','No confirmed material misrepresentation'))
    $trig = @($f.verdict.hard_gates_triggered)
    foreach($g in $gates){
      $failed = $trig -contains $g[0]
      $cls = if($failed){'fail'}else{'pass'}; $mk = if($failed){'&#10007;'}else{'&#10003;'}
      [void]$sb.Append("<div class=`"gate $cls`"><span class=`"mark`">$mk</span><span>$(Esc $g[1])</span></div>")
    }
    [void]$sb.Append("</div>")
  }

  # ---- Factor tables ----
  $claimById = @{}; if ($f.claims){ foreach($c in $f.claims){ $claimById[$c.claim_id] = $c } }
  function Factor-Table($title, $prefix, $extra){
    $t = [System.Text.StringBuilder]::new()
    [void]$t.Append("<$hh>$title</$hh>")
    if ($extra){ [void]$t.Append($extra) }
    [void]$t.Append("<table><thead><tr><th>#</th><th>Factor</th><th class=`"num`">Wt</th><th class=`"num`">Sub-score</th><th class=`"num`">Contrib.</th><th>Conf.</th><th>Summary &amp; sources</th></tr></thead><tbody>")
    foreach($fac in ($f.factors | Where-Object { $_.id -like "$prefix*" })){
      $col = ScoreColor([double]$fac.subscore)
      $contrib = [Math]::Round(([double]$fac.subscore * [double]$fac.weight)/100,1)
      $cites = ''
      if ($fac.claim_ids){ foreach($cid in $fac.claim_ids){ if($claimById.ContainsKey($cid)){ $cites += (CiteMarkers $claimById[$cid].citations $srcIdx) } } }
      [void]$t.Append("<tr><td>$(Esc $fac.id)</td><td>$(Esc $fac.name)</td><td class=`"num`">$($fac.weight)</td>")
      [void]$t.Append("<td class=`"num`"><span class=`"sbar`"><i style=`"width:$($fac.subscore)%;background:$col`"></i></span>$($fac.subscore)</td>")
      [void]$t.Append("<td class=`"num`">$contrib</td><td>$(ConfDots([int]$fac.confidence))</td>")
      [void]$t.Append("<td>$(Esc $fac.summary)$cites</td></tr>")
    }
    [void]$t.Append("</tbody></table>")
    return $t.ToString()
  }
  [void]$sb.Append((Factor-Table 'Immigration risk breakdown' 'I' $null))

  # Capital-stack bar for financial section if present in F1 summary metadata
  $stackExtra = $null
  $f1 = $f.factors | Where-Object { $_.id -eq 'F1' } | Select-Object -First 1
  if ($f1 -and $f1.summary){ $stackExtra = "<div class=`"sub`" style=`"margin-bottom:6px`">Capital-stack note: $(Esc $f1.summary)</div>" }
  [void]$sb.Append((Factor-Table 'Financial risk breakdown' 'F' $stackExtra))

  # ---- Claim-by-claim ledger ----
  if ($f.claims -and $f.claims.Count){
    [void]$sb.Append("<$hh>Verification ledger</$hh><div class=`"panel ledger`">")
    [void]$sb.Append("<div class=`"filters`"><button class=`"active`" onclick=`"eb5Filter(this,'ALL')`">All</button><button onclick=`"eb5Filter(this,'VERIFIED')`">Verified</button><button onclick=`"eb5Filter(this,'CONTRADICTED')`">Contradicted</button><button onclick=`"eb5Filter(this,'UNVERIFIABLE')`">Unverifiable</button></div>")
    [void]$sb.Append("<table><thead><tr><th>Claim (as issuer states it)</th><th>Issuer source</th><th>Verdict</th><th>Conf.</th><th>Independent finding</th></tr></thead><tbody>")
    foreach($c in $f.claims){
      $cm = CiteMarkers $c.citations $srcIdx
      $note = Esc $c.note
      if ($c.verdict -eq 'UNVERIFIABLE' -and -not $c.note){ $note = "No independent source found; relying solely on issuer representation." }
      [void]$sb.Append("<tr data-verdict=`"$($c.verdict)`"><td>$(Esc $c.claim_text)</td><td class=`"mini`">$(Esc $c.source_of_claim)</td>")
      [void]$sb.Append("<td><span class=`"badge b-$($c.verdict)`">$($c.verdict)</span></td><td>$(ConfDots([int]$c.confidence))</td>")
      [void]$sb.Append("<td>$note $cm</td></tr>")
    }
    [void]$sb.Append("</tbody></table></div>")
  }

  # ---- Red-flag log ----
  if ($f.red_flags -and $f.red_flags.Count){
    [void]$sb.Append("<$hh>Red-flag log</$hh><div class=`"panel`">")
    $order=@{critical=0;high=1;medium=2;low=3}
    foreach($r in ($f.red_flags | Sort-Object { $order[$_.severity] })){
      [void]$sb.Append("<div style=`"margin:10px 0`"><span class=`"sev $($r.severity)`"></span><strong>$(Esc $r.title)</strong> <span class=`"mini`">($($r.severity))</span>")
      [void]$sb.Append("<div>$(Esc $r.detail)</div>")
      if ($r.issuer_framing){ [void]$sb.Append("<div class=`"mini`"><em>Issuer framing vs reality:</em> $(Esc $r.issuer_framing)</div>") }
      if ($r.source_indices){ $m = ($r.source_indices | ForEach-Object { "<a href=`"#src$_`">[$_]</a>" }) -join ''; [void]$sb.Append("<sup class=`"cite`">$m</sup>") }
      [void]$sb.Append("</div>")
    }
    [void]$sb.Append("</div>")
  }

  # ---- Data-gap log ----
  if ($f.data_gaps -and $f.data_gaps.Count){
    [void]$sb.Append("<$hh>Data gaps (could not be independently verified)</$hh><div class=`"panel`"><table><thead><tr><th>Item</th><th>Why</th><th>Closes with</th></tr></thead><tbody>")
    foreach($d in $f.data_gaps){ [void]$sb.Append("<tr><td>$(Esc $d.item)</td><td class=`"mini`">$(Esc $d.why)</td><td>$(Esc $d.closes_with)</td></tr>") }
    [void]$sb.Append("</tbody></table></div>")
  }

  # ---- Checklist ----
  if ($f.checklist -and $f.checklist.Count){
    [void]$sb.Append("<$hh>Pre-investment verification checklist</$hh><div class=`"panel`"><ul class=`"check`">")
    foreach($it in $f.checklist){
      $lab = switch($it.status){ 'pass'{'PASS'} 'fail'{'FAIL'} 'manual'{'DO THIS'} default{'UNKNOWN'} }
      [void]$sb.Append("<li><span class=`"st $($it.status)`">$lab</span><span>$(Esc $it.text) <span class=`"mini`">[$($it.category)]</span></span></li>")
    }
    [void]$sb.Append("</ul></div>")
  }

  # ---- Sources ----
  if ($srcIdx.list.Count){
    [void]$sb.Append("<$hh>Sources</$hh><div class=`"panel`"><ol>")
    for($i=0;$i -lt $srcIdx.list.Count;$i++){
      $s=$srcIdx.list[$i]; $n=$i+1; $tcls="t$($s.tier)"
      $issuer = if ($s.is_issuer){ " <span class=`"mini`">(issuer - not independent)</span>" } else { '' }
      $acc = if ($s.accessed){ " <span class=`"mini`">accessed $(Esc $s.accessed)</span>" } else { '' }
      [void]$sb.Append("<li id=`"src$n`"><span class=`"pill $tcls`">T$($s.tier)</span> <a href=`"$(Esc $s.url)`" target=`"_blank`" rel=`"noopener`">$(Esc $s.title)</a>$issuer$acc</li>")
    }
    [void]$sb.Append("</ol></div>")
  }
  return $sb.ToString()
}

# ----- Load findings -----
# Allow a single comma-joined value (e.g. when invoked via -File "a.json,b.json").
if ($Findings.Count -eq 1 -and $Findings[0] -match ',') { $Findings = $Findings[0] -split '\s*,\s*' }
$docs = @()
foreach($path in $Findings){
  if (-not (Test-Path -LiteralPath $path)) { throw "Findings file not found: $path" }
  $docs += (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}
$tpl = Get-Content -LiteralPath $Template -Raw

if (-not $Compare){
  $body = Render-Body $docs[0] $false
  $title = "EB-5 DD - $($docs[0].project.name)"
} else {
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.Append("<h1>EB-5 project comparison</h1><div class=`"sub`">$($docs.Count) projects &middot; lower score = lower risk</div>")
  # Matrix
  [void]$sb.Append("<h2>Summary matrix</h2><div class=`"panel`"><table><thead><tr><th>Project</th><th>Verdict</th><th class=`"num`">Imm risk</th><th class=`"num`">Fin risk</th><th class=`"num`">Avg conf</th><th class=`"num`">Critical flags</th><th class=`"num`">Data gaps</th></tr></thead><tbody>")
  $bestImm = (($docs | ForEach-Object { [int]$_.scores.immigration.composite }) | Measure-Object -Minimum).Minimum
  $bestFin = (($docs | ForEach-Object { [int]$_.scores.financial.composite }) | Measure-Object -Minimum).Minimum
  foreach($d in $docs){
    $crit = @($d.red_flags | Where-Object { $_.severity -eq 'critical' }).Count
    $gaps = @($d.data_gaps).Count
    $ic = if([int]$d.scores.immigration.composite -eq $bestImm){' class="best num"'}else{' class="num"'}
    $fc = if([int]$d.scores.financial.composite -eq $bestFin){' class="best num"'}else{' class="num"'}
    [void]$sb.Append("<tr><td>$(Esc $d.project.name)</td><td><span class=`"badge b-VERIFIED`" style=`"background:none;border:none`"><span class=`"chip $($d.verdict.decision)`" style=`"font-size:11px;padding:2px 8px`">$($d.verdict.decision)</span></span></td>")
    [void]$sb.Append("<td$ic>$($d.scores.immigration.composite)</td><td$fc>$($d.scores.financial.composite)</td>")
    [void]$sb.Append("<td class=`"num`">$([Math]::Round([double]$d.scores.avg_confidence,1))</td><td class=`"num`">$crit</td><td class=`"num`">$gaps</td></tr>")
  }
  [void]$sb.Append("</tbody></table><p class=`"mini`">A lower risk score can simply mean less was independently verified &mdash; always read the Avg-confidence column alongside the scores.</p></div>")

  # Heatmap across 19 factors
  $allIds = @('I1','I2','I3','I4','I5','I6','I7','I8','I9','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10')
  [void]$sb.Append("<h2>Factor heatmap</h2><div class=`"panel`" style=`"overflow-x:auto`"><table class=`"heat`"><thead><tr><th>Project</th>")
  foreach($id in $allIds){ [void]$sb.Append("<th class=`"num`">$id</th>") }
  [void]$sb.Append("</tr></thead><tbody>")
  foreach($d in $docs){
    [void]$sb.Append("<tr><td>$(Esc $d.project.name)</td>")
    foreach($id in $allIds){
      $fac = $d.factors | Where-Object { $_.id -eq $id } | Select-Object -First 1
      if ($fac){ $col=ScoreColor([double]$fac.subscore); [void]$sb.Append("<td class=`"cell`" style=`"background:$col`" title=`"$(Esc $fac.name)`">$($fac.subscore)</td>") }
      else { [void]$sb.Append("<td class=`"cell`" style=`"background:var(--panel2)`">-</td>") }
    }
    [void]$sb.Append("</tr>")
  }
  [void]$sb.Append("</tbody></table></div>")

  # Embedded per-project reports
  [void]$sb.Append("<h2>Full reports</h2>")
  foreach($d in $docs){
    [void]$sb.Append("<details class=`"acc`"><summary>$(Esc $d.project.name) &mdash; $($d.verdict.decision) &middot; Imm $($d.scores.immigration.composite) / Fin $($d.scores.financial.composite)</summary><div class=`"body`">")
    [void]$sb.Append((Render-Body $d $true))
    [void]$sb.Append("</div></details>")
  }
  $body = $sb.ToString()
  $title = "EB-5 comparison ($($docs.Count) projects)"
}

$html = $tpl.Replace('{{TITLE}}', (Esc $title)).Replace('{{BODY}}', $body).Replace('{{GENERATED_AT}}', (Esc $GeneratedAt)).Replace('{{DISCLAIMER}}', $DISCLAIMER)
Set-Content -LiteralPath $Out -Value $html -Encoding UTF8
Write-Output "Wrote $Out"

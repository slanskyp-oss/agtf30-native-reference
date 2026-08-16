$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$agtf = Join-Path $root 'external/AGTF30'
$tmats = Join-Path $root 'external/T-MATS'
$out = Join-Path $root 'evidence/source'
if (-not (Test-Path $agtf)) { throw 'AGTF30 exact source is missing.' }
if (-not (Test-Path $tmats)) { throw 'T-MATS exact source is missing.' }

$sourceFiles = Get-ChildItem -Path (Join-Path $agtf 'AGTF30') -File -Recurse | Where-Object { $_.Extension -in '.mdl','.m' }
$canteraHits = @()
$tmatsRefs = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in $sourceFiles) {
  $text = Get-Content -Raw -LiteralPath $f.FullName
  if ($text -match '(?i)Cantera|TMATSC|Cantera_Enabled') {
    $canteraHits += $f.FullName.Substring($agtf.Length + 1).Replace('\','/')
  }
  foreach ($m in [regex]::Matches($text, '(?im)(?:ReferenceBlock|SourceBlock)\s+"([^"]*TMATS[^"]*)"')) {
    [void]$tmatsRefs.Add($m.Groups[1].Value)
  }
  foreach ($m in [regex]::Matches($text, '(?im)"([^"]*(?:Lib_[A-Za-z0-9_]+_TMATS|[A-Za-z0-9_]+_TMATS)[^"]*)"')) {
    [void]$tmatsRefs.Add($m.Groups[1].Value)
  }
}

$canteraRequired = $canteraHits.Count -gt 0
$record = [ordered]@{
  schema='NREF_SOURCE_DEPENDENCY_ASSESSMENT_v1.0'
  AGTF30_commit=(git -C $agtf rev-parse HEAD).Trim()
  TMATS_commit=(git -C $tmats rev-parse HEAD).Trim()
  assessment_utc=(Get-Date).ToUniversalTime().ToString('o')
  inspected_AGTF30_files=$sourceFiles.Count
  tmats_block_or_library_references=@($tmatsRefs | Sort-Object)
  cantera_markers=@($canteraHits | Sort-Object -Unique)
  CANTERA_REQUIRED=$canteraRequired
  policy_if_required='STOP_UNLESS_CONTROLLED_HISTORICALLY_APPROPRIATE_DEPENDENCY_IS_PROVISIONED'
  standard_TMATS_path_only_for_P1=(-not $canteraRequired)
}
$record | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $out 'source_dependency_assessment.json')

$md = @()
$md += '# Source dependency assessment'
$md += ''
$md += ('- AGTF30 commit: `{0}`' -f $record.AGTF30_commit)
$md += ('- T-MATS commit: `{0}`' -f $record.TMATS_commit)
$md += "- Files inspected: $($record.inspected_AGTF30_files)"
$md += "- CANTERA_REQUIRED = $($record.CANTERA_REQUIRED.ToString().ToUpperInvariant())"
$md += ''
$md += '## T-MATS block/library references discovered in exact AGTF30 source'
if ($tmatsRefs.Count -eq 0) { $md += '- No explicit library-link string extracted by static scanner; runtime model load remains the next verification layer.' }
else { foreach ($x in ($tmatsRefs | Sort-Object)) { $md += ('- `{0}`' -f $x) } }
$md += ''
$md += '## Cantera markers'
if ($canteraHits.Count -eq 0) { $md += '- None found in the exact AGTF30 execution-source files scanned.' }
else { foreach ($x in ($canteraHits | Sort-Object -Unique)) { $md += ('- `{0}`' -f $x) } }
$md | Set-Content -Encoding utf8 (Join-Path $out 'source_dependency_assessment.md')

if ($canteraRequired) { throw 'CANTERA_REQUIRED=TRUE. Controlled dependency is not provisioned; STOP before build.' }

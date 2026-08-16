$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statusFile=Join-Path $root 'evidence/status/controlled_run_status.json'
$warningFile=Join-Path $root 'evidence/status/semantic_warning_review.json'
if ($env:FINALIZE_STATUS_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: final status classification step failed.' }
if ($env:PACKAGE_EVIDENCE_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: post-run evidence/manifest step failed.' }
if ($env:UPLOAD_EVIDENCE_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: primary controlled evidence artifact upload failed.' }
if ($env:RECORD_TRANSPORT_OUTCOME -ne 'success' -or $env:UPLOAD_TRANSPORT_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: artifact transport record failed.' }
if (-not (Test-Path $statusFile)) { throw 'EVIDENCE_PACKAGING_FAIL: controlled run status file missing.' }
$s=Get-Content -Raw $statusFile | ConvertFrom-Json
if ($s.status -ne 'P1_NATIVE_GENERIC_SOURCE_REFERENCE_CANDIDATE_PASS_SEMANTIC_DECK') {
  throw "CONTROLLED P1 SEMANTIC ACQUISITION FAIL: $($s.status) — $($s.detail)"
}
if ($s.semantic_authority -ne 'SEMANTIC_DECK_CANDIDATE_REQUIRES_OVERSIGHT_ACCEPTANCE') {
  throw "SEMANTIC AUTHORITY FAIL: $($s.semantic_authority)"
}
if (-not (Test-Path $warningFile)) { throw 'SEMANTIC_WARNING_REVIEW_FAIL: machine-readable semantic warning review missing.' }
$w=Get-Content -Raw $warningFile | ConvertFrom-Json
if ($w.status -notin @('PASS_NO_WARNING_OBSERVED','PASS_REVIEWED_WARNING_CONTEXT')) {
  throw "SEMANTIC_WARNING_REVIEW_FAIL: $($w.status) — $($w.detail)"
}
Write-Host 'Controlled semantic-deck candidate PASS: reviewed mapping executed on all mandatory native points. Downstream Oversight artifact acceptance is still required.'

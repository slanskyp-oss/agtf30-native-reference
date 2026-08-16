$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statusFile=Join-Path $root 'evidence/status/controlled_run_status.json'
if ($env:FINALIZE_STATUS_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: final status classification step failed.' }
if ($env:PACKAGE_EVIDENCE_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: post-run evidence/manifest step failed.' }
if ($env:UPLOAD_EVIDENCE_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: primary controlled evidence artifact upload failed.' }
if ($env:RECORD_TRANSPORT_OUTCOME -ne 'success' -or $env:UPLOAD_TRANSPORT_OUTCOME -ne 'success') { throw 'EVIDENCE_PACKAGING_FAIL: artifact transport record failed.' }
if (-not (Test-Path $statusFile)) { throw 'EVIDENCE_PACKAGING_FAIL: controlled run status file missing.' }
$s=Get-Content -Raw $statusFile | ConvertFrom-Json
if ($s.status -ne 'P1_COMPAT_NATIVE_SOURCE_CANDIDATE_PASS_SCHEMA_DISCOVERY') {
  throw "CONTROLLED P1 ACQUISITION FAIL: $($s.status) — $($s.detail)"
}
Write-Host 'Controlled first-run candidate PASS: native execution qualified for schema discovery only. Semantic P1 deck still requires reviewed mapping and rerun.'

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $root 'transport'
New-Item -ItemType Directory -Force $out | Out-Null
if (-not $env:PRIMARY_ARTIFACT_DIGEST) { throw 'Primary artifact digest output is missing.' }
[ordered]@{
 schema='NREF_CI_ARTIFACT_TRANSPORT_RECORD_v1.2'
 artifact_name='AGTF30_NATIVE_V130_CONTROLLED_P1_EVIDENCE'
 artifact_digest=$env:PRIMARY_ARTIFACT_DIGEST
 artifact_id=$env:PRIMARY_ARTIFACT_ID
 artifact_url=$env:PRIMARY_ARTIFACT_URL
 GITHUB_REPOSITORY=$env:GITHUB_REPOSITORY
 expected_harness_sha=$env:EXPECTED_HARNESS_SHA
 actual_harness_sha=$env:GITHUB_SHA
 GITHUB_SHA=$env:GITHUB_SHA
 GITHUB_WORKFLOW=$env:GITHUB_WORKFLOW
 GITHUB_RUN_ID=$env:GITHUB_RUN_ID
 GITHUB_RUN_ATTEMPT=$env:GITHUB_RUN_ATTEMPT
 acquisition_utc=(Get-Date).ToUniversalTime().ToString('o')
 permanence='TRANSPORT_ONLY_IMPORT_TO_CONTROLLED_DOWNSTREAM_STORAGE_REQUIRED'
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $out 'ci_artifact_transport_record.json')

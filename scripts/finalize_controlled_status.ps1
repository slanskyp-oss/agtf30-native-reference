$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statusDir=Join-Path $root 'evidence/status'; New-Item -ItemType Directory -Force $statusDir | Out-Null

$status='OTHER_TOOLING_FAIL'; $detail='Unclassified controlled acquisition state.'
$harnessFile=Join-Path $root 'evidence/harness/harness_identity.json'
if ($env:HARNESS_IDENTITY_OUTCOME -ne 'success') {
  if (Test-Path $harnessFile) {
    $h=Get-Content -Raw $harnessFile | ConvertFrom-Json
    if ($h.reviewed_sha_gate_status -eq 'UNREVIEWED_HARNESS_SHA_FAIL') { $status='UNREVIEWED_HARNESS_SHA_FAIL'; $detail=$h.reviewed_sha_gate_detail }
    else { $status='HARNESS_IDENTITY_FAIL'; $detail='Harness identity binding failed.' }
  } else { $status='HARNESS_IDENTITY_FAIL'; $detail='Harness identity binding failed before identity evidence was written.' }
}
elseif ($env:PUBLIC_ALLOWLIST_OUTCOME -ne 'success') { $status='OTHER_TOOLING_FAIL'; $detail='Public allowlist/reference-grid preflight failed.' }
elseif ($env:RUNNER_IDENTITY_OUTCOME -ne 'success') { $status='RUNNER_IDENTITY_FAIL'; $detail='Runner/tooling/Python provenance capture failed.' }
elseif ($env:PWSH_SYNTAX_OUTCOME -ne 'success') { $status='OTHER_TOOLING_FAIL'; $detail='Harness PowerShell syntax preflight failed under runner pwsh; source acquisition was not started.' }
elseif ($env:SOURCE_CHECKOUT_OUTCOME -ne 'success') { $status='SOURCE_CHECKOUT_FAIL'; $detail='Exact NASA source checkout/identity/archive failed.' }
elseif ($env:DEPENDENCY_PREFLIGHT_OUTCOME -ne 'success') {
  $depFile=Join-Path $root 'evidence/source/source_dependency_assessment.json'
  $dep=$null
  if (Test-Path $depFile) {
    try { $dep=Get-Content -Raw $depFile | ConvertFrom-Json }
    catch { $dep=$null }
  }
  if ($null -ne $dep -and $dep.CANTERA_REQUIRED -eq $true) {
    $status='SOURCE_DEPENDENCY_FAIL'
    $detail='Machine-readable dependency assessment positively establishes CANTERA_REQUIRED=true; controlled dependency is not provisioned.'
  }
  else {
    $status='OTHER_TOOLING_FAIL'
    $detail='Dependency preflight process failed without positive machine-readable evidence of a required source dependency; do not classify as SOURCE_DEPENDENCY_FAIL.'
  }
}
elseif ($env:SOURCE_CLEAN_PRE_OUTCOME -ne 'success') { $status='SOURCE_DIRTY_FAIL'; $detail='Pre-build tracked source cleanliness failed.' }
elseif ($env:MATLAB_SETUP_OUTCOME -ne 'success') { $status='MATLAB_SETUP_FAIL'; $detail='MATLAB/Simulink setup action failed.' }
elseif ($env:MATLAB_ACTION_PREFLIGHT_OUTCOME -ne 'success') { $status='MATLAB_ACTION_PREFLIGHT_FAIL'; $detail='Pinned MATLAB run-command preflight failed; native source acquisition was not started.' }
elseif ($env:SOURCE_CLEAN_POST_OUTCOME -ne 'success') { $status='SOURCE_DIRTY_FAIL'; $detail='Post-run tracked source cleanliness failed.' }
else {
  $nativeStatusFile=Join-Path $statusDir 'native_stage_status.json'
  $summary=Join-Path $root 'evidence/parsed/native_reference_execution_summary.csv'
  $native=$null
  if (Test-Path $nativeStatusFile) { $native=Get-Content -Raw $nativeStatusFile | ConvertFrom-Json }

  if ($null -ne $native -and $native.status -eq 'P1_COMPAT_NATIVE_SOURCE_CANDIDATE_PASS_SCHEMA_DISCOVERY' -and $env:NATIVE_RUN_OUTCOME -eq 'success') {
    $status=$native.status; $detail=$native.message
  }
  elseif ($null -ne $native -and $native.status -eq 'COMPILER_SELECTION_FAIL') { $status='COMPILER_SELECTION_FAIL'; $detail=$native.message }
  elseif ($null -ne $native -and $native.status -eq 'BUILD_FAIL') { $status='BUILD_FAIL'; $detail=$native.message }
  elseif (Test-Path $summary) {
    $rows=Import-Csv $summary
    if ($rows.Run_Status -contains 'SOURCE_CLAMPED_INPUT_REJECTED') { $status='SOURCE_CLAMPED_INPUT_REJECTED'; $detail='At least one requested native point was changed/clamped by source setup. See point-level input-binding evidence.' }
    elseif ($rows.Run_Status -contains 'SOURCE_EXECUTION_ERROR') { $status='SOURCE_EXECUTION_ERROR'; $detail='At least one native point entered source execution and produced a point-level source execution exception. See complete summary/raw evidence.' }
    elseif ($rows.Run_Status -contains 'SOURCE_NONCONVERGED') { $status='SOURCE_NONCONVERGED'; $detail='At least one executed native point produced native out_SS with an explicit nonconverged convergence quantity. See point-level out_SS evidence.' }
    elseif ($rows.Run_Status -contains 'PARSER_FAIL') { $status='PARSER_FAIL'; $detail='Native output existed but schema-discovery parsing/evidence extraction failed for at least one point.' }
    elseif ($env:NATIVE_RUN_OUTCOME -ne 'success') { $status='MATLAB_ACTION_EXECUTION_FAIL'; $detail='Authoritative pinned MATLAB run-command step failed, but available native evidence does not support a more specific source/build classification. Do not infer source nonconvergence.' }
    else { $status='OTHER_TOOLING_FAIL'; $detail='Native summary exists but does not support a recognized controlled status.' }
  }
  elseif ($env:NATIVE_RUN_OUTCOME -ne 'success') {
    $status='MATLAB_ACTION_EXECUTION_FAIL';
    $detail='Authoritative pinned MATLAB run-command step failed without complete point summary. Licensing, MATLAB startup, GitHub step timeout, or other action/tooling failure may be responsible; available workflow metadata does not justify SOURCE_NONCONVERGED or timeout certainty.'
  }
  else { $status='OTHER_TOOLING_FAIL'; $detail='Native MATLAB action reported success but expected final native evidence/status was not established.' }
}

[ordered]@{
 schema='NREF_CONTROLLED_P1_RUN_STATUS_v1.2.2'
 RUN_REASON=$env:RUN_REASON
 classification=$env:P1_CLASSIFICATION
 status=$status
 detail=$detail
 expected_harness_sha=$env:EXPECTED_HARNESS_SHA
 actual_harness_sha=$env:GITHUB_SHA
 first_run_semantic_authority=($status -eq 'P1_COMPAT_NATIVE_SOURCE_CANDIDATE_PASS_SCHEMA_DISCOVERY' ? 'SCHEMA_DISCOVERY_ONLY_REVIEWED_SEMANTIC_MAPPING_AND_RERUN_REQUIRED' : 'NOT_ESTABLISHED')
 GITHUB_REPOSITORY=$env:GITHUB_REPOSITORY
 GITHUB_REF=$env:GITHUB_REF
 GITHUB_WORKFLOW=$env:GITHUB_WORKFLOW
 GITHUB_SHA=$env:GITHUB_SHA
 GITHUB_RUN_ID=$env:GITHUB_RUN_ID
 GITHUB_RUN_ATTEMPT=$env:GITHUB_RUN_ATTEMPT
 utc=(Get-Date).ToUniversalTime().ToString('o')
 step_outcomes=[ordered]@{
  harness_identity=$env:HARNESS_IDENTITY_OUTCOME; public_allowlist=$env:PUBLIC_ALLOWLIST_OUTCOME; runner_identity=$env:RUNNER_IDENTITY_OUTCOME;
  pwsh_syntax=$env:PWSH_SYNTAX_OUTCOME;
  source_checkout=$env:SOURCE_CHECKOUT_OUTCOME; dependency_preflight=$env:DEPENDENCY_PREFLIGHT_OUTCOME; source_clean_pre=$env:SOURCE_CLEAN_PRE_OUTCOME;
  matlab_setup=$env:MATLAB_SETUP_OUTCOME; matlab_action_preflight=$env:MATLAB_ACTION_PREFLIGHT_OUTCOME; native_run=$env:NATIVE_RUN_OUTCOME;
  source_clean_post=$env:SOURCE_CLEAN_POST_OUTCOME
 }
 status_semantics=[ordered]@{
  pwsh_syntax_failure='Harness parser failure under runner pwsh is OTHER_TOOLING_FAIL and blocks source acquisition before MATLAB/native execution.'
  source_dependency_fail_requires='SOURCE_DEPENDENCY_FAIL requires readable positive machine-readable dependency evidence with CANTERA_REQUIRED=true; an undifferentiated preflight process failure is tooling failure.'
  source_nonconverged_requires='Native source execution plus explicit native convergence quantity indicating nonconvergence.'
  matlab_action_execution_fail='Used when the pinned MATLAB action fails without evidence sufficient for a more specific source/build classification.'
  timeout_classification='NATIVE_STEP_TIMEOUT_TOOLING_FAIL may be assigned only when workflow/run metadata explicitly establishes timeout; this finalizer does not infer timeout from a generic failed action outcome.'
 }
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $statusDir 'controlled_run_status.json')

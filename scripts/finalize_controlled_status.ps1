$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statusDir=Join-Path $root 'evidence/status'; New-Item -ItemType Directory -Force $statusDir | Out-Null
function Get-SemanticWarningReview {
  param([string]$Root)
  $mappingFile=Join-Path $Root 'config/p1_semantic_mapping.json'
  $diaryFile=Join-Path $Root 'evidence/logs/matlab_execution_diary.txt'
  $result=[ordered]@{
    schema='NREF_SEMANTIC_WARNING_REVIEW_v1.0'
    status='FAIL'
    detail='Warning review not completed.'
    expected_point=$null
    expected_warning=$null
    baseline_reviewed_occurrence_count=$null
    observed_count=0
    observed=@()
  }
  if (-not (Test-Path $mappingFile)) { $result.detail='Reviewed semantic mapping file missing.'; return $result }
  if (-not (Test-Path $diaryFile)) { $result.detail='MATLAB diary missing.'; return $result }
  try { $mapping=Get-Content -Raw $mappingFile | ConvertFrom-Json }
  catch { $result.detail='Reviewed semantic mapping JSON unreadable.'; return $result }
  if ($null -eq $mapping.warning_policy) { $result.detail='Warning policy missing from reviewed mapping.'; return $result }
  $expectedPoint=[string]$mapping.warning_policy.assignment
  $warning=[string]$mapping.warning_policy.source_warning
  $baselineCount=[int]$mapping.warning_policy.occurrence_count_run3
  $result.expected_point=$expectedPoint
  $result.expected_warning=$warning
  $result.baseline_reviewed_occurrence_count=$baselineCount
  $currentPoint=$null
  $observed=@()
  foreach ($line in Get-Content -LiteralPath $diaryFile) {
    if ($line -match '^NREF POINT START index=\d+ point=(\S+)\s*$') { $currentPoint=$Matches[1]; continue }
    if ($line -match '^NREF POINT END point=(\S+)\s+status=') {
      if ($currentPoint -eq $Matches[1]) { $currentPoint=$null }
      continue
    }
    if ($line.Contains($warning)) { $observed += [pscustomobject]@{ point_id=$currentPoint; line=$line } }
  }
  $result.observed_count=@($observed).Count
  $result.observed=@($observed)
  $unexpected=@($observed | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.point_id) -or [string]$_.point_id -ne $expectedPoint })
  if ($unexpected.Count -gt 0) {
    $result.status='FAIL_UNEXPECTED_WARNING_CONTEXT'
    $result.detail='One or more reviewed CoreNoz warning occurrences were uncontextualized or occurred at an unreviewed point.'
    return $result
  }
  if (@($observed).Count -eq 0) {
    $result.status='PASS_NO_WARNING_OBSERVED'
    $result.detail='Reviewed CoreNoz warning was not observed in the current controlled semantic rerun.'
    return $result
  }
  if (@($observed).Count -gt $baselineCount) {
    $result.status='FAIL_WARNING_COUNT_DRIFT'
    $result.detail="Reviewed warning occurrence count increased from baseline $baselineCount to $(@($observed).Count). Oversight review required."
    return $result
  }
  $result.status='PASS_REVIEWED_WARNING_CONTEXT'
  $result.detail="All observed reviewed CoreNoz warning occurrences were directly bracketed by runner point context for $expectedPoint."
  return $result
}


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
  $semanticSummary=Join-Path $root 'evidence/parsed/semantic_reference_execution_summary.csv'
  $native=$null
  if (Test-Path $nativeStatusFile) { $native=Get-Content -Raw $nativeStatusFile | ConvertFrom-Json }

  if ($null -ne $native -and $native.status -eq 'P1_NATIVE_GENERIC_SOURCE_REFERENCE_CANDIDATE_PASS_SEMANTIC_DECK' -and $env:NATIVE_RUN_OUTCOME -eq 'success') {
    if (-not (Test-Path $semanticSummary)) {
      $status='OTHER_TOOLING_FAIL'; $detail='Native stage reported semantic-deck candidate success but semantic execution summary is missing.'
    } else {
      $semRows=@(Import-Csv $semanticSummary)
      $expectedSemanticCount=@(Import-Csv (Join-Path $root 'config/reference_grid.csv') | Where-Object { $_.Execution_Action -eq 'EXECUTE' }).Count
      $badSem=@($semRows | Where-Object { $_.Semantic_Status -ne 'SEMANTIC_EXTRACTION_PASS_CANDIDATE' })
      $missingSemEvidence=@($semRows | Where-Object {
        $_.Semantic_Status -eq 'SEMANTIC_EXTRACTION_PASS_CANDIDATE' -and
        ([string]::IsNullOrWhiteSpace([string]$_.Semantic_Evidence) -or
         -not (Test-Path (Join-Path (Join-Path $root 'evidence') ([string]$_.Semantic_Evidence))))
      })
      if ($semRows.Count -ne $expectedSemanticCount -or $badSem.Count -gt 0 -or $missingSemEvidence.Count -gt 0) {
        $status='OTHER_TOOLING_FAIL'
        $detail="Semantic candidate success consistency failed: rows=$($semRows.Count) expected=$expectedSemanticCount bad_status=$($badSem.Count) missing_evidence=$($missingSemEvidence.Count)."
      } else {
        $warningReview=Get-SemanticWarningReview -Root $root
        $warningReview | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $statusDir 'semantic_warning_review.json')
        if ($warningReview.status -in @('PASS_NO_WARNING_OBSERVED','PASS_REVIEWED_WARNING_CONTEXT')) {
          $status=$native.status; $detail=$native.message
        } else {
          $status='SEMANTIC_WARNING_REVIEW_FAIL'; $detail=$warningReview.detail
        }
      }
    }
  }
  elseif ($null -ne $native -and $native.status -eq 'COMPILER_SELECTION_FAIL') { $status='COMPILER_SELECTION_FAIL'; $detail=$native.message }
  elseif ($null -ne $native -and $native.status -eq 'BUILD_FAIL') { $status='BUILD_FAIL'; $detail=$native.message }
  elseif (Test-Path $summary) {
    $rows=Import-Csv $summary
    $semRows=$null
    if (Test-Path $semanticSummary) { $semRows=@(Import-Csv $semanticSummary) }
    if ($rows.Run_Status -contains 'SOURCE_CLAMPED_INPUT_REJECTED') { $status='SOURCE_CLAMPED_INPUT_REJECTED'; $detail='At least one requested native point was changed/clamped by source setup. See point-level input-binding evidence.' }
    elseif ($rows.Run_Status -contains 'SOURCE_EXECUTION_ERROR') { $status='SOURCE_EXECUTION_ERROR'; $detail='At least one native point entered source execution and produced a point-level source execution exception. See complete summary/raw evidence.' }
    elseif ($rows.Run_Status -contains 'SOURCE_NONCONVERGED') { $status='SOURCE_NONCONVERGED'; $detail='At least one executed native point produced native out_SS with an explicit nonconverged convergence quantity. See point-level out_SS evidence.' }
    elseif ($rows.Run_Status -contains 'PARSER_FAIL') { $status='PARSER_FAIL'; $detail='Native output existed but generic schema-inventory parsing/evidence extraction failed for at least one point.' }
    elseif ($null -ne $semRows -and $semRows.Semantic_Status -contains 'SEMANTIC_PARSER_FAIL') { $status='SEMANTIC_PARSER_FAIL'; $detail='At least one converged native point failed reviewed semantic extraction. Native PASS/convergence evidence remains separately preserved.' }
    elseif ($env:NATIVE_RUN_OUTCOME -ne 'success') { $status='MATLAB_ACTION_EXECUTION_FAIL'; $detail='Authoritative pinned MATLAB run-command step failed, but available native/semantic evidence does not support a more specific source/build/semantic classification. Do not infer source nonconvergence.' }
    else { $status='OTHER_TOOLING_FAIL'; $detail='Native summary exists but does not support a recognized controlled status.' }
  }
  elseif ($env:NATIVE_RUN_OUTCOME -ne 'success') {
    $status='MATLAB_ACTION_EXECUTION_FAIL';
    $detail='Authoritative pinned MATLAB run-command step failed without complete point summary. Licensing, MATLAB startup, GitHub step timeout, or other action/tooling failure may be responsible; available workflow metadata does not justify SOURCE_NONCONVERGED or timeout certainty.'
  }
  else { $status='OTHER_TOOLING_FAIL'; $detail='Native MATLAB action reported success but expected final native evidence/status was not established.' }
}

[ordered]@{
 schema='NREF_CONTROLLED_P1_RUN_STATUS_v1.2.5'
 RUN_REASON=$env:RUN_REASON
 classification=$env:P1_CLASSIFICATION
 status=$status
 detail=$detail
 expected_harness_sha=$env:EXPECTED_HARNESS_SHA
 actual_harness_sha=$env:GITHUB_SHA
 semantic_authority=($status -eq 'P1_NATIVE_GENERIC_SOURCE_REFERENCE_CANDIDATE_PASS_SEMANTIC_DECK' ? 'SEMANTIC_DECK_CANDIDATE_REQUIRES_OVERSIGHT_ACCEPTANCE' : 'NOT_ESTABLISHED')
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
  semantic_parser_fail='SEMANTIC_PARSER_FAIL is derived from Semantic_Status while native Run_Status remains PASS_NATIVE_CONVERGED for a converged point; raw MAT remains authoritative.'
  semantic_warning_review='Current-run reviewed CoreNoz warning occurrences are machine-readably contextualized from runner point markers; zero occurrences pass, reviewed-point occurrences pass only up to the reviewed baseline count, and unexpected context/count drift fails.'
  matlab_action_execution_fail='Used when the pinned MATLAB action fails without evidence sufficient for a more specific source/build classification.'
  timeout_classification='NATIVE_STEP_TIMEOUT_TOOLING_FAIL may be assigned only when workflow/run metadata explicitly establishes timeout; this finalizer does not infer timeout from a generic failed action outcome.'
 }
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $statusDir 'controlled_run_status.json')

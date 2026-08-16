$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $root 'evidence/harness'
New-Item -ItemType Directory -Force $out | Out-Null

$expectedRaw = $env:EXPECTED_HARNESS_SHA
$actual = $env:GITHUB_SHA
$head = (git -C $root rev-parse HEAD).Trim()
$expectedValid = [bool]($expectedRaw -match '^[0-9a-fA-F]{40}$')
$expected = if ($expectedValid) { $expectedRaw.ToLowerInvariant() } else { $expectedRaw }
$actualNorm = if ($actual) { $actual.ToLowerInvariant() } else { $actual }
$headNorm = $head.ToLowerInvariant()
$gateStatus = 'PASS'
$gateDetail = 'Reviewed harness SHA matches GITHUB_SHA and checked-out HEAD.'
if (-not $expectedValid) { $gateStatus='UNREVIEWED_HARNESS_SHA_FAIL'; $gateDetail='expected_harness_sha is not exactly 40 hexadecimal characters.' }
elseif (-not $actual) { $gateStatus='UNREVIEWED_HARNESS_SHA_FAIL'; $gateDetail='GITHUB_SHA is missing.' }
elseif ($actualNorm -ne $expected) { $gateStatus='UNREVIEWED_HARNESS_SHA_FAIL'; $gateDetail='GITHUB_SHA does not match expected_harness_sha.' }
elseif ($headNorm -ne $expected) { $gateStatus='UNREVIEWED_HARNESS_SHA_FAIL'; $gateDetail='Checked-out harness HEAD does not match expected_harness_sha.' }

$record = [ordered]@{
  schema = 'NREF_HARNESS_IDENTITY_v1.2'
  canonical_harness_identity = if ($gateStatus -eq 'PASS') { $headNorm } else { $null }
  expected_harness_sha = $expectedRaw
  expected_harness_sha_normalized = $expected
  actual_github_sha = $actual
  checked_out_head = $head
  reviewed_sha_gate_status = $gateStatus
  reviewed_sha_gate_detail = $gateDetail
  GITHUB_REPOSITORY = $env:GITHUB_REPOSITORY
  GITHUB_SHA = $env:GITHUB_SHA
  GITHUB_REF = $env:GITHUB_REF
  GITHUB_WORKFLOW = $env:GITHUB_WORKFLOW
  GITHUB_RUN_ID = $env:GITHUB_RUN_ID
  GITHUB_RUN_ATTEMPT = $env:GITHUB_RUN_ATTEMPT
  GITHUB_ACTOR = $env:GITHUB_ACTOR
  RUN_REASON = $env:RUN_REASON
  acquisition_start_utc = (Get-Date).ToUniversalTime().ToString('o')
}
$record | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $out 'harness_identity.json')

if ($gateStatus -ne 'PASS') {
  throw "UNREVIEWED_HARNESS_SHA_FAIL: $gateDetail expected='$expectedRaw' actual='$actual' HEAD='$head'"
}

$archive = Join-Path $out 'harness_exact_git_commit.zip'
git -C $root archive --format=zip --output=$archive $head
$archiveHash = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
"$archiveHash  harness_exact_git_commit.zip" | Set-Content -Encoding ascii (Join-Path $out 'harness_archive_sha256.txt')

$patterns = @('.github/workflows/','scripts/','config/','tools/','docs/','README.md','REPOSITORY_SETUP.md','action_dependency_register.json','PUBLIC_CONTENT_ALLOWLIST.json','PUBLIC_REPOSITORY_POLICY.md','TEMPLATE_SHA256SUMS.txt')
$tracked = git -C $root ls-tree -r --name-only $head
$rows = @()
foreach ($rel in $tracked) {
  $include = $false
  foreach ($p in $patterns) { if ($rel -eq $p -or $rel.StartsWith($p)) { $include = $true; break } }
  if ($include) {
    $full = Join-Path $root $rel
    if (-not (Test-Path $full)) { throw "Tracked harness file missing from working tree: $rel" }
    $rows += [pscustomobject]@{ path=$rel; sha256=(Get-FileHash -Algorithm SHA256 $full).Hash.ToLowerInvariant() }
  }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $out 'harness_file_hashes.json')

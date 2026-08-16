$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ext = Join-Path $root 'external'
$evidence = Join-Path $root 'evidence/source'
New-Item -ItemType Directory -Force $ext, $evidence | Out-Null

$agtfExpected = 'a1521a76930df92ae5611f3454fc612a8b574cdf'
$tmatsExpected = '56066ead5f461c33286425bd928ff77ed03c5244'
$agtf = Join-Path $ext 'AGTF30'
$tmats = Join-Path $ext 'T-MATS'
if (Test-Path $agtf) { Remove-Item -Recurse -Force $agtf }
if (Test-Path $tmats) { Remove-Item -Recurse -Force $tmats }

git clone --no-checkout https://github.com/nasa/AGTF30.git $agtf
git -C $agtf checkout --detach $agtfExpected
git clone --no-checkout https://github.com/nasa/T-MATS.git $tmats
git -C $tmats checkout --detach $tmatsExpected

$agtfHead = (git -C $agtf rev-parse HEAD).Trim()
$tmatsHead = (git -C $tmats rev-parse HEAD).Trim()
if ($agtfHead -ne $agtfExpected) { throw "AGTF30 identity mismatch: $agtfHead" }
if ($tmatsHead -ne $tmatsExpected) { throw "T-MATS identity mismatch: $tmatsHead" }

if ((git -C $agtf diff --name-only HEAD).Count -ne 0) { throw 'AGTF30 tracked source is dirty immediately after checkout.' }
if ((git -C $tmats diff --name-only HEAD).Count -ne 0) { throw 'T-MATS tracked source is dirty immediately after checkout.' }

$agtfArchive = Join-Path $evidence 'AGTF30_source_exact_commit.zip'
$tmatsArchive = Join-Path $evidence 'TMATS_v130_source_exact_commit.zip'
git -C $agtf archive --format=zip --output=$agtfArchive HEAD
git -C $tmats archive --format=zip --output=$tmatsArchive HEAD
$agtfArchiveSha = (Get-FileHash -Algorithm SHA256 $agtfArchive).Hash.ToLowerInvariant()
$tmatsArchiveSha = (Get-FileHash -Algorithm SHA256 $tmatsArchive).Hash.ToLowerInvariant()

[ordered]@{
  schema='NREF_NATIVE_SOURCE_IDENTITY_v1.1'
  AGTF30_repository='nasa/AGTF30'
  AGTF30_commit=$agtfHead
  AGTF30_checkout='DETACHED_EXACT_COMMIT'
  AGTF30_source_archive_sha256=$agtfArchiveSha
  TMATS_repository='nasa/T-MATS'
  TMATS_commit=$tmatsHead
  TMATS_declared_tag='v1.3.0'
  TMATS_checkout='DETACHED_EXACT_COMMIT'
  TMATS_source_archive_sha256=$tmatsArchiveSha
  source_modifications='NONE'
  acquisition_utc=(Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $evidence 'source_identity_actual.json')

@(
  "$agtfArchiveSha  AGTF30_source_exact_commit.zip",
  "$tmatsArchiveSha  TMATS_v130_source_exact_commit.zip"
) | Set-Content -Encoding ascii (Join-Path $evidence 'source_archive_sha256.txt')

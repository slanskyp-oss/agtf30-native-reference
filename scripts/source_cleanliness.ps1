param([Parameter(Mandatory=$true)][ValidateSet('PRE_BUILD','POST_RUN')] [string]$Phase)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $root 'evidence/source'
New-Item -ItemType Directory -Force $out | Out-Null
$repos = @(
  @{ Name='AGTF30'; Path=(Join-Path $root 'external/AGTF30') },
  @{ Name='TMATS'; Path=(Join-Path $root 'external/T-MATS') }
)
$records=@()
foreach ($r in $repos) {
  if (-not (Test-Path $r.Path)) { throw "$($r.Name) source path missing for cleanliness check." }
  $trackedDiff = @(git -C $r.Path diff --name-only HEAD)
  $cachedDiff = @(git -C $r.Path diff --cached --name-only)
  $untracked = @(git -C $r.Path ls-files --others --exclude-standard)
  $trackedClean = ($trackedDiff.Count -eq 0 -and $cachedDiff.Count -eq 0)
  git -C $r.Path status --porcelain=v1 --untracked-files=all | Out-File -Encoding utf8 (Join-Path $out "$($r.Name)_git_status_$($Phase.ToLowerInvariant()).txt")
  git -C $r.Path diff --no-ext-diff | Out-File -Encoding utf8 (Join-Path $out "$($r.Name)_tracked_diff_$($Phase.ToLowerInvariant()).patch")
  $records += [pscustomobject]@{
    repository=$r.Name
    phase=$Phase
    head=(git -C $r.Path rev-parse HEAD).Trim()
    tracked_clean=$trackedClean
    tracked_diff_files=$trackedDiff
    cached_diff_files=$cachedDiff
    untracked_generated_files=$untracked
  }
  if (-not $trackedClean) { throw "$($r.Name) tracked source is dirty at $Phase. P1 evidence qualification fails." }
}
$records | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $out "source_cleanliness_$($Phase.ToLowerInvariant()).json")

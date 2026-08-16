$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$evidence=Join-Path $root 'evidence'
if (-not (Test-Path $evidence)) { throw 'Evidence root does not exist.' }

Copy-Item -Force (Join-Path $root 'action_dependency_register.json') (Join-Path $evidence 'harness/action_dependency_register.json')
Copy-Item -Force (Join-Path $root 'config/reference_grid.csv') (Join-Path $evidence 'harness/reference_grid.csv')
Copy-Item -Force (Join-Path $root 'config/input_match_tolerances.json') (Join-Path $evidence 'harness/input_match_tolerances.json')
Copy-Item -Force (Join-Path $root 'config/toolchain_policy.json') (Join-Path $evidence 'harness/toolchain_policy.json')
Copy-Item -Force (Join-Path $root 'config/timeout_policy.json') (Join-Path $evidence 'harness/timeout_policy.json')
Copy-Item -Force (Join-Path $root 'config/p1_semantic_mapping.json') (Join-Path $evidence 'harness/p1_semantic_mapping.json')
Copy-Item -Force (Join-Path $root 'docs/P1_SEMANTIC_MAPPING_BASIS.md') (Join-Path $evidence 'harness/P1_SEMANTIC_MAPPING_BASIS.md')
Copy-Item -Force (Join-Path $root 'PUBLIC_CONTENT_ALLOWLIST.json') (Join-Path $evidence 'harness/PUBLIC_CONTENT_ALLOWLIST.json')
Copy-Item -Force (Join-Path $root 'README.md') (Join-Path $evidence 'harness/README.md')

$manifest = Join-Path $evidence 'SHA256SUMS.txt'
if (Test-Path $manifest) { Remove-Item $manifest -Force }
Get-ChildItem -Path $evidence -File -Recurse | Where-Object { $_.FullName -ne $manifest } | Sort-Object FullName | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
  $rel = $_.FullName.Substring($evidence.Length + 1).Replace('\','/')
  "$hash  $rel"
} | Set-Content -Encoding ascii $manifest
if (-not (Test-Path $manifest)) { throw 'Evidence SHA256 manifest generation failed.' }

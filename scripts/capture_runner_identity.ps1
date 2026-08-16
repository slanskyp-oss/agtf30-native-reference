$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $root 'evidence/environment'
New-Item -ItemType Directory -Force $out | Out-Null

$runnerVars = [ordered]@{}
Get-ChildItem Env: | Where-Object { $_.Name -match '^(RUNNER_|ImageOS$|ImageVersion$|ACTIONS_RUNNER_|GITHUB_ACTIONS$)' } | Sort-Object Name | ForEach-Object { $runnerVars[$_.Name] = $_.Value }

$os = Get-ComputerInfo
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = $null
if (Test-Path $vswhere) { $vs = (& $vswhere -all -products * -format json | ConvertFrom-Json) }
$toolsets = @()
$vsRoot = Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio/2022'
if (Test-Path $vsRoot) {
  Get-ChildItem $vsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $msvc = Join-Path $_.FullName 'VC/Tools/MSVC'
    if (Test-Path $msvc) { Get-ChildItem $msvc -Directory | ForEach-Object { $toolsets += $_.FullName } }
  }
}

$listenerVersion = $null
$runnerRoot = Split-Path $env:RUNNER_TEMP -Parent
$listener = Get-ChildItem -Path $runnerRoot -Filter 'Runner.Listener.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
  try { $listenerVersion = (& $listener.FullName --version 2>&1 | Out-String).Trim() } catch { $listenerVersion = "ERROR: $($_.Exception.Message)" }
}

$pythonVersion = (& python --version 2>&1 | Out-String).Trim()
$pythonExecutable = (& python -c "import sys; print(sys.executable)" 2>&1 | Out-String).Trim()
$pythonCommand = (Get-Command python -ErrorAction Stop).Source

$record = [ordered]@{
  schema='NREF_RUNNER_IDENTITY_v1.2'
  acquisition_utc=(Get-Date).ToUniversalTime().ToString('o')
  RUNNER_OS=$env:RUNNER_OS
  RUNNER_ARCH=$env:RUNNER_ARCH
  ImageOS=$env:ImageOS
  ImageVersion=$env:ImageVersion
  runner_version_where_exposed=$listenerVersion
  windows_product_name=$os.WindowsProductName
  windows_version=$os.WindowsVersion
  os_build_number=$os.OsBuildNumber
  os_architecture=$os.OsArchitecture
  visual_studio_instances=$vs
  installed_msvc_toolset_paths=$toolsets
  python_version=$pythonVersion
  python_executable=$pythonExecutable
  python_command_path=$pythonCommand
  exposed_runner_environment=$runnerVars
}
$record | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $out 'runner_identity.json')

$diag = @()
$diag += "RUNNER_OS=$env:RUNNER_OS"
$diag += "RUNNER_ARCH=$env:RUNNER_ARCH"
$diag += "ImageOS=$env:ImageOS"
$diag += "ImageVersion=$env:ImageVersion"
$diag += "WindowsProductName=$($os.WindowsProductName)"
$diag += "WindowsVersion=$($os.WindowsVersion)"
$diag += "OsBuildNumber=$($os.OsBuildNumber)"
$diag += "RunnerVersionWhereExposed=$listenerVersion"
$diag += "VSWHERE=$vswhere"
$diag += "MSVC_TOOLSETS=$($toolsets -join ';')"
$diag += "PYTHON_VERSION=$pythonVersion"
$diag += "PYTHON_EXECUTABLE=$pythonExecutable"
$diag += "PYTHON_COMMAND_PATH=$pythonCommand"
$diag | Set-Content -Encoding utf8 (Join-Path $out 'runner_identity.txt')

Get-ComputerInfo | Out-File -Encoding utf8 (Join-Path $out 'windows_computer_info.txt')
if (Test-Path $vswhere) { & $vswhere -all -products * -format json | Out-File -Encoding utf8 (Join-Path $out 'vswhere_all.json') }

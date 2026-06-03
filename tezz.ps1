$root = (Split-Path -Parent $MyInvocation.MyCommand.Path).TrimEnd('\','/')
$probe = Join-Path $root "tools\probes\tls_connect_ex_probe.tn"
$tezzcEnv = $env:TEZZC
$candidates = @()
if ($tezzcEnv) { $candidates += $tezzcEnv }
$candidates += @(
  (Join-Path $root "bin\tezzc.exe"),
  (Join-Path $root "bin\tezzc-windows-x64.exe"),
  (Join-Path $root "build\tezzc.exe"),
  (Join-Path $root "tezzc.exe")
)
$tezzc = $null
function Test-TezzCompiler([string]$candidate, [string]$probePath) {
  if (-not (Test-Path $candidate)) { return $false }
  if (-not (Test-Path $probePath)) { return $true }
  & $candidate check $probePath *> $null
  return ($LASTEXITCODE -eq 0)
}
function Invoke-TezzBootstrap([string]$rootPath) {
  $script = Join-Path $rootPath "tools\build_core_strict.ps1"
  if (-not (Test-Path $script)) { return $false }
  Write-Host "tezz: bootstrapping compiler from source..."
  & powershell -ExecutionPolicy Bypass -File $script *> $null
  return ($LASTEXITCODE -eq 0)
}
foreach ($candidate in $candidates) {
  if (Test-TezzCompiler $candidate $probe) {
    $tezzc = $candidate
    break
  }
}
if (-not $tezzc) {
  $cmd = Get-Command tezzc.exe -ErrorAction SilentlyContinue
  if ($cmd -and (Test-TezzCompiler $cmd.Source $probe)) { $tezzc = $cmd.Source }
}
if (-not $tezzc) {
  $cmd = Get-Command tezzc-windows-x64.exe -ErrorAction SilentlyContinue
  if ($cmd -and (Test-TezzCompiler $cmd.Source $probe)) { $tezzc = $cmd.Source }
}
if (-not $tezzc) {
  [void](Invoke-TezzBootstrap $root)
  foreach ($candidate in $candidates) {
    if (Test-TezzCompiler $candidate $probe) {
      $tezzc = $candidate
      break
    }
  }
}
if (-not $tezzc) {
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      $tezzc = $candidate
      break
    }
  }
}
if (-not $tezzc) {
  $cmd = Get-Command tezzc.exe -ErrorAction SilentlyContinue
  if ($cmd) { $tezzc = $cmd.Source }
}
if (-not $tezzc) {
  $cmd = Get-Command tezzc-windows-x64.exe -ErrorAction SilentlyContinue
  if ($cmd) { $tezzc = $cmd.Source }
}
if (-not $tezzc) {
  Write-Error "tezz: compiler not found (expected bin\tezzc.exe, a source build via tools\build_core_strict.ps1, or PATH tezzc.exe)."
  exit 1
}
$tool = Join-Path $root "tools\tezz.tn"
if (-not (Test-Path $tool)) {
  Write-Error "tezz: tools\tezz.tn not found next to launcher."
  exit 1
}
$env:Path = (Join-Path $root "bin") + ";" + (Join-Path $root "build") + ";" + $root + ";" + $env:Path
$env:TEZZ_SDK_ROOT = $root
& $tezzc run --bc $tool -- @args --tezzc $tezzc --sdk-root $root
exit $LASTEXITCODE

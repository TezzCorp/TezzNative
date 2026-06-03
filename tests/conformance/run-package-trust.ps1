param(
  [string]$Tezzc = "",
  [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
} else {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$passed = 0
$failed = 0

function Pass([string]$Name) {
  $script:passed++
  Write-Host "PASS package-trust/$Name"
}

function Fail([string]$Name, [string]$Message) {
  $script:failed++
  Write-Host "FAIL package-trust/$Name :: $Message"
}

function Check([string]$Name, [scriptblock]$Body) {
  try {
    & $Body
    Pass $Name
  } catch {
    Fail $Name $_.Exception.Message
  }
}

function Required-Path([string]$Relative) {
  $path = Join-Path $RepoRoot $Relative
  if (-not (Test-Path -LiteralPath $path)) {
    throw "missing $Relative"
  }
  return $path
}

function Read-KvFile([string]$Path) {
  $map = [ordered]@{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }
    $parts = $trimmed -split "\s*=\s*", 2
    if ($parts.Count -ne 2) {
      throw "malformed key/value line in $Path`: $line"
    }
    $map[$parts[0]] = $parts[1]
  }
  return $map
}

function Assert-SemVer([string]$Value, [string]$Label) {
  if ($Value -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)([-+][0-9A-Za-z.-]+)?$') {
    throw "$Label is not semantic version x.y.z: $Value"
  }
}

function Assert-Name([string]$Value, [string]$Label) {
  if ($Value -notmatch '^[a-z][a-z0-9_]*$') {
    throw "$Label has invalid package name: $Value"
  }
}

function Hash8-Bytes([byte[]]$Bytes) {
  $h = 5381
  foreach ($b in $Bytes) {
    $h = ((($h -shl 5) + $h + [int]$b) -band 0x7FFFFFFF)
  }
  return "{0:X8}" -f $h
}

function Hash8-Text([string]$Text) {
  return Hash8-Bytes ([System.Text.Encoding]::ASCII.GetBytes($Text))
}

function Read-LockEntries([string]$Path) {
  $rows = @()
  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }
    $parts = $trimmed -split "\s+"
    if ($parts.Count -ne 3) {
      throw "malformed lock entry: $line"
    }
    $name, $version = $parts[0] -split "@", 2
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
      throw "malformed lock package token: $($parts[0])"
    }
    $rows += [pscustomobject]@{
      Token = $parts[0]
      Name = $name
      Version = $version
      Checksum = $parts[1]
      Url = $parts[2]
      Raw = $trimmed
    }
  }
  return $rows
}

function Read-RegistryEntries([string]$Path) {
  $rows = @()
  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }
    $parts = $trimmed -split "\s+"
    if ($parts.Count -ne 3) {
      throw "malformed registry entry: $line"
    }
    $name, $version = $parts[0] -split "@", 2
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
      throw "malformed registry package token: $($parts[0])"
    }
    $rows += [pscustomobject]@{
      Token = $parts[0]
      Name = $name
      Version = $version
      Url = $parts[1]
      Checksum = $parts[2]
      Raw = $trimmed
    }
  }
  return $rows
}

function Assert-MetaLine([string]$Path, [string]$Kind) {
  $lines = Get-Content -LiteralPath $Path
  if ($lines.Count -lt 2) {
    throw "$Kind file is empty"
  }
  $meta = $lines[0]
  if ($meta -notmatch "^# $Kind v1 lines=([0-9]+) payload=([0-9A-F]{8}) key=([A-Za-z0-9]+|none) sig=([A-Za-z0-9]+|none)$") {
    throw "bad $Kind metadata line: $meta"
  }
  $payloadLines = @($lines | Where-Object { $_.Trim().Length -gt 0 -and -not $_.Trim().StartsWith("#") })
  $payload = ""
  if ($payloadLines.Count -gt 0) {
    $payload = ($payloadLines -join "`n") + "`n"
  }
  $lineCount = [int]$Matches[1]
  $payloadHash = $Matches[2]
  if ($lineCount -ne $payloadLines.Count) {
    throw "$Kind metadata line count mismatch: expected $lineCount got $($payloadLines.Count)"
  }
  $actual = Hash8-Text $payload
  if ($actual -ne $payloadHash) {
    throw "$Kind payload hash mismatch: expected $payloadHash got $actual"
  }
}

function Write-PackageDocs([array]$LockEntries, [string]$OutPath) {
  $dir = Split-Path -Parent $OutPath
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $lines = @(
    "# Generated Package Inventory",
    "",
    "Source: tezz.mod + tezz.lock",
    "",
    "| Package | Version | Checksum | Source |",
    "| --- | --- | --- | --- |"
  )
  foreach ($entry in $LockEntries | Sort-Object Name) {
    $lines += ("| ``{0}`` | ``{1}`` | ``{2}`` | {3} |" -f $entry.Name, $entry.Version, $entry.Checksum, $entry.Url)
  }
  Set-Content -LiteralPath $OutPath -Value ($lines -join "`n") -Encoding ASCII
}

$modPath = Join-Path $RepoRoot "tezz.mod"
$lockPath = Join-Path $RepoRoot "tezz.lock"
$registryPath = Join-Path $RepoRoot "registry.tnx"
$toolPath = Join-Path $RepoRoot "tools\tezz.tn"
$docPath = Join-Path $RepoRoot "docs\PACKAGE_TRUST.md"

$metadata = $null
$deps = [ordered]@{}
$lockEntries = @()
$registryEntries = @()

Check "surface-files" {
  foreach ($rel in @("tezz", "tezz.cmd", "tezz.ps1", "tezz.mod", "tezz.lock", "registry.tnx", "tools\tezz.tn", "docs\PACKAGE_TRUST.md")) {
    [void](Required-Path $rel)
  }
}

Check "tezz-mod-semver" {
  $script:metadata = Read-KvFile $modPath
  foreach ($required in @("name", "version", "module_root", "registry", "registry_lib")) {
    if (-not $script:metadata.Contains($required)) {
      throw "missing $required in tezz.mod"
    }
  }
  Assert-Name $script:metadata["name"] "project name"
  Assert-SemVer $script:metadata["version"] "project version"
  if ($script:metadata["module_root"] -ne "lib") {
    throw "module_root must be lib"
  }
  if ($script:metadata["registry"] -ne "https://tn.tezzcorp.com/registry.tnx") {
    throw "unexpected registry URL"
  }
  if ($script:metadata["registry_lib"] -ne "https://tn.tezzcorp.com/download/sdk/lib/") {
    throw "unexpected registry_lib URL"
  }
  foreach ($key in $script:metadata.Keys) {
    if ($key.StartsWith("dep.")) {
      $name = $key.Substring(4)
      Assert-Name $name "dependency"
      Assert-SemVer $script:metadata[$key] "dependency $name"
      $script:deps[$name] = $script:metadata[$key]
    }
    if ($key.StartsWith("optdep.")) {
      $name = $key.Substring(7)
      Assert-Name $name "optional dependency"
      Assert-SemVer $script:metadata[$key] "optional dependency $name"
    }
  }
  if ($script:deps.Count -lt 7) {
    throw "expected first-party dependency inventory"
  }
}

Check "lock-format-and-metadata" {
  Assert-MetaLine $lockPath "lock-meta"
  $script:lockEntries = Read-LockEntries $lockPath
  $seen = @{}
  $previous = ""
  foreach ($entry in $script:lockEntries) {
    Assert-Name $entry.Name "lock package"
    Assert-SemVer $entry.Version "lock package $($entry.Name)"
    if ($entry.Checksum -notmatch '^[0-9A-F]{8}$') {
      throw "bad checksum for $($entry.Token)"
    }
    if (-not $entry.Url.StartsWith($script:metadata["registry_lib"])) {
      throw "lock provenance URL mismatch for $($entry.Token)"
    }
    if ($seen.ContainsKey($entry.Token)) {
      throw "duplicate lock token $($entry.Token)"
    }
    $seen[$entry.Token] = $true
    if ($previous -ne "" -and [string]::CompareOrdinal($previous, $entry.Raw) -gt 0) {
      throw "lock entries are not sorted"
    }
    $previous = $entry.Raw
  }
}

Check "registry-format-and-metadata" {
  Assert-MetaLine $registryPath "registry-meta"
  $script:registryEntries = Read-RegistryEntries $registryPath
  $seen = @{}
  $previous = ""
  foreach ($entry in $script:registryEntries) {
    Assert-Name $entry.Name "registry package"
    Assert-SemVer $entry.Version "registry package $($entry.Name)"
    if ($entry.Checksum -notmatch '^[0-9A-F]{8}$') {
      throw "bad registry checksum for $($entry.Token)"
    }
    if (-not $entry.Url.StartsWith($script:metadata["registry_lib"])) {
      throw "registry provenance URL mismatch for $($entry.Token)"
    }
    if ($seen.ContainsKey($entry.Token)) {
      throw "duplicate registry token $($entry.Token)"
    }
    $seen[$entry.Token] = $true
    if ($previous -ne "" -and [string]::CompareOrdinal($previous, $entry.Raw) -gt 0) {
      throw "registry entries are not sorted"
    }
    $previous = $entry.Raw
  }
}

Check "lock-registry-parity" {
  $registryByToken = @{}
  foreach ($entry in $script:registryEntries) {
    $registryByToken[$entry.Token] = $entry
  }
  foreach ($entry in $script:lockEntries) {
    if (-not $registryByToken.ContainsKey($entry.Token)) {
      throw "missing registry entry for $($entry.Token)"
    }
    $reg = $registryByToken[$entry.Token]
    if ($reg.Url -ne $entry.Url -or $reg.Checksum -ne $entry.Checksum) {
      throw "registry mismatch for $($entry.Token)"
    }
  }
  foreach ($name in $script:deps.Keys) {
    $token = "$name@$($script:deps[$name])"
    if (-not $registryByToken.ContainsKey($token)) {
      throw "missing registry entry for dependency $token"
    }
  }
}

Check "local-checksums" {
  foreach ($entry in $script:lockEntries) {
    $libPath = Join-Path $RepoRoot ("lib\" + $entry.Name + ".tn")
    if (-not (Test-Path -LiteralPath $libPath)) {
      throw "missing local package source lib/$($entry.Name).tn"
    }
    $actual = Hash8-Bytes ([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $libPath).Path))
    if ($actual -ne $entry.Checksum) {
      throw "checksum mismatch for $($entry.Name): expected $($entry.Checksum) got $actual"
    }
  }
}

Check "tool-command-surface" {
  $source = Get-Content -LiteralPath $toolPath -Raw
  foreach ($needle in @("cmd_init", "cmd_add", "cmd_remove", "cmd_update", "cmd_lock", "cmd_publish", "cmd_test", "cmd_build_path")) {
    if (-not $source.Contains("fn $needle")) {
      throw "missing function $needle"
    }
  }
  foreach ($cmd in @("init", "add", "remove", "update", "lock", "publish", "test", "build")) {
    if (-not $source.Contains("streq(cmd, `"$cmd`")")) {
      throw "missing dispatch for $cmd"
    }
  }
  foreach ($literal in @("tezz add <name@ver>", "tezz remove <name>", "publish: registry metadata ready", "--release")) {
    if (-not $source.Contains($literal)) {
      throw "missing command help/literal: $literal"
    }
  }
}

Check "launcher-contract" {
  $posix = Get-Content -LiteralPath (Join-Path $RepoRoot "tezz") -Raw
  $ps = Get-Content -LiteralPath (Join-Path $RepoRoot "tezz.ps1") -Raw
  $cmd = Get-Content -LiteralPath (Join-Path $RepoRoot "tezz.cmd") -Raw
  foreach ($content in @($posix, $ps, $cmd)) {
    if (-not $content.Contains("tools/tezz.tn") -and -not $content.Contains("tools\tezz.tn")) {
      throw "launcher missing tools/tezz.tn"
    }
    if (-not $content.Contains("--sdk-root")) {
      throw "launcher missing --sdk-root handoff"
    }
  }
}

Check "generated-package-docs" {
  $out = Join-Path $RepoRoot "build\package_docs.generated.md"
  Write-PackageDocs $script:lockEntries $out
  $generated = Get-Content -LiteralPath $out -Raw
  foreach ($name in @("std", "io", "net", "math", "vec", "arena")) {
    if (-not $generated.Contains("``$name``")) {
      throw "generated package docs missing $name"
    }
  }
}

Check "first-party-target-docs" {
  $doc = Get-Content -LiteralPath $docPath -Raw
  foreach ($target in @("JSON", "CLI argument parser", "Logging", "Config file support", "Regex", "SQLite binding", "HTTP client/server", "Testing assertions", "Benchmark helpers")) {
    if (-not $doc.Contains($target)) {
      throw "docs missing first-party target: $target"
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($Tezzc)) {
  Check "tool-source-check" {
    $compiler = (Resolve-Path -LiteralPath $Tezzc).Path
    $tool = (Resolve-Path -LiteralPath $toolPath).Path
    & $compiler check $tool
    if ($LASTEXITCODE -ne 0) {
      throw "tezz tool failed compiler check with exit $LASTEXITCODE"
    }
  }

  Check "tool-command-workflow" {
    $compiler = (Resolve-Path -LiteralPath $Tezzc).Path
    $tool = (Resolve-Path -LiteralPath $toolPath).Path
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tezz-package-trust-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      Push-Location $tmp
      & $compiler run --bc $tool -- init . --name package_probe --template cli --tezzc $compiler --sdk-root $RepoRoot
      if ($LASTEXITCODE -ne 0) {
        throw "tezz init failed with exit $LASTEXITCODE"
      }
      New-Item -ItemType Directory -Force -Path "lib" | Out-Null
      foreach ($name in @("std", "time", "task", "io")) {
        Copy-Item -Force (Join-Path $RepoRoot ("lib\" + $name + ".tn")) (Join-Path "lib" ($name + ".tn"))
      }
      & $compiler run --bc $tool -- remove io --tezzc $compiler --sdk-root $RepoRoot
      if ($LASTEXITCODE -ne 0) {
        throw "tezz remove failed with exit $LASTEXITCODE"
      }
      if ((Get-Content -LiteralPath "tezz.mod" -Raw).Contains("dep.io")) {
        throw "tezz remove left dep.io in tezz.mod"
      }
      $ioEntry = $script:lockEntries | Where-Object { $_.Name -eq "io" } | Select-Object -First 1
      if (-not $ioEntry) {
        throw "root lock missing io entry"
      }
      New-Item -ItemType Directory -Force -Path ".tezz\cache" | Out-Null
      Copy-Item -Force (Join-Path $RepoRoot "lib\io.tn") ".tezz\cache\io-0.1.0.tn"
      & $compiler run --bc $tool -- add io@0.1.0 $ioEntry.Url $ioEntry.Checksum --tezzc $compiler --sdk-root $RepoRoot
      if ($LASTEXITCODE -ne 0) {
        throw "tezz add failed with exit $LASTEXITCODE"
      }
      if (-not (Test-Path -LiteralPath "lib\io.tn")) {
        throw "tezz add did not restore lib/io.tn"
      }
      & $compiler run --bc $tool -- publish build\registry_probe.tnx --tezzc $compiler --sdk-root $RepoRoot
      if ($LASTEXITCODE -ne 0) {
        throw "tezz publish failed with exit $LASTEXITCODE"
      }
      if (-not (Test-Path -LiteralPath "build\registry_probe.tnx")) {
        throw "tezz publish did not write registry output"
      }
      $published = Get-Content -LiteralPath "build\registry_probe.tnx" -Raw
      foreach ($token in @("std@0.1.0", "io@0.1.0", "time@0.1.0", "task@0.1.0")) {
        if (-not $published.Contains($token)) {
          throw "published registry missing $token"
        }
      }
    } finally {
      Pop-Location
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

Write-Host "PACKAGE_TRUST_SUMMARY passed=$passed failed=$failed"
if ($failed -ne 0) {
  exit 1
}

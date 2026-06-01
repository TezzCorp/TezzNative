param(
  [string]$SiteRoot = "TezzCorp_WebSites/tn_tezzcorp_com",
  [string]$OutFile = "",
  [string]$BaseUrl = "https://tn.tezzcorp.com",
  [string[]]$Include = @()
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ResolvedSiteRoot = if ([System.IO.Path]::IsPathRooted($SiteRoot)) {
  (Resolve-Path $SiteRoot).Path
} else {
  (Resolve-Path (Join-Path $RepoRoot $SiteRoot)).Path
}

if ([string]::IsNullOrWhiteSpace($OutFile)) {
  $OutFile = Join-Path $ResolvedSiteRoot "download/release_manifest.json"
} elseif (-not [System.IO.Path]::IsPathRooted($OutFile)) {
  $OutFile = Join-Path $RepoRoot $OutFile
}

$VersionPath = Join-Path $RepoRoot "version.json"
$VersionInfo = [ordered]@{}
if (Test-Path -LiteralPath $VersionPath) {
  $parsed = Get-Content -LiteralPath $VersionPath -Raw | ConvertFrom-Json
  foreach ($prop in $parsed.PSObject.Properties) {
    $VersionInfo[$prop.Name] = $prop.Value
  }
}

$DefaultInclude = @(
  "download/tezznative-sdk.zip",
  "download/tezznative-sdk.zip.sha256",
  "download/tezznative-sdk-linux.tar.gz",
  "download/tezznative-sdk-linux.tar.gz.sha256",
  "download/tezzc-linux-x64.gz",
  "download/tezzc-linux-x64.gz.sha256",
  "download/install.ps1",
  "download/install.sh",
  "download/install.cmd",
  "registry.tnx",
  "download/sdk/version.json",
  "download/sdk/tezz.mod",
  "download/sdk/tezz.lock",
  "download/sdk/registry.tnx",
  "download/sdk/bin/tezzc.exe",
  "download/sdk/bin/tezzc-windows-x64.exe",
  "download/sdk/bin/tezzc-linux-x64",
  "download/sdk/lib/std.tn",
  "download/sdk/lib/io.tn",
  "download/sdk/lib/net.tn"
)

$RelativeFiles = if ($Include.Count -gt 0) { $Include } else { $DefaultInclude }
$Artifacts = @()
foreach ($rel in ($RelativeFiles | Sort-Object -Unique)) {
  $normalized = ($rel -replace "\\", "/").TrimStart("/")
  $path = Join-Path $ResolvedSiteRoot ($normalized -replace "/", [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path)) {
    continue
  }
  $file = Get-Item -LiteralPath $path
  if (-not $file.PSIsContainer) {
    $Artifacts += [ordered]@{
      path = $normalized
      url = $BaseUrl.TrimEnd("/") + "/" + $normalized
      bytes = $file.Length
      sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToUpperInvariant()
    }
  }
}

if ($Artifacts.Count -eq 0) {
  throw "No release artifacts found under $ResolvedSiteRoot"
}

$Manifest = [ordered]@{
  schema = "tezznative.release-manifest.v1"
  generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  project = "TezzNative"
  version = if ($VersionInfo.Contains("version")) { [string]$VersionInfo["version"] } else { "" }
  channel = if ($VersionInfo.Contains("channel")) { [string]$VersionInfo["channel"] } else { "" }
  api = if ($VersionInfo.Contains("api")) { [string]$VersionInfo["api"] } else { "" }
  base_url = $BaseUrl.TrimEnd("/")
  policy = [ordered]@{
    checksum_algorithm = "SHA-256"
    install_rule = "Installers must fail closed when archive checksums do not match."
    telemetry_rule = "No install telemetry is required for compiler/runtime use; portal events are best-effort and non-blocking."
  }
  artifacts = $Artifacts
}

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
$json = $Manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutFile -Value $json -Encoding ASCII
$manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutFile).Hash.ToUpperInvariant()
Set-Content -LiteralPath ($OutFile + ".sha256") -Value "$manifestHash  $([System.IO.Path]::GetFileName($OutFile))" -Encoding ASCII

Write-Host "release manifest: $OutFile"
Write-Host "artifacts: $($Artifacts.Count)"
Write-Host "sha256: $manifestHash"

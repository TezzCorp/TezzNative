param(
  [string]$ManifestPath = "TezzCorp_WebSites/tn_tezzcorp_com/download/release_manifest.json",
  [string]$SiteRoot = "TezzCorp_WebSites/tn_tezzcorp_com"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ResolvedManifestPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
  (Resolve-Path $ManifestPath).Path
} else {
  (Resolve-Path (Join-Path $RepoRoot $ManifestPath)).Path
}
$ResolvedSiteRoot = if ([System.IO.Path]::IsPathRooted($SiteRoot)) {
  (Resolve-Path $SiteRoot).Path
} else {
  (Resolve-Path (Join-Path $RepoRoot $SiteRoot)).Path
}

$manifest = Get-Content -LiteralPath $ResolvedManifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne "tezznative.release-manifest.v1") {
  throw "Unsupported release manifest schema: $($manifest.schema)"
}
if (-not $manifest.artifacts -or $manifest.artifacts.Count -lt 1) {
  throw "Release manifest contains no artifacts"
}

$sidecar = $ResolvedManifestPath + ".sha256"
if (Test-Path -LiteralPath $sidecar) {
  $expectedManifestHash = ((Get-Content -LiteralPath $sidecar -Raw).Trim() -split "\s+")[0].ToUpperInvariant()
  $actualManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ResolvedManifestPath).Hash.ToUpperInvariant()
  if ($expectedManifestHash -ne $actualManifestHash) {
    throw "Manifest sidecar mismatch: expected $expectedManifestHash got $actualManifestHash"
  }
}

$failures = New-Object System.Collections.Generic.List[string]
foreach ($artifact in $manifest.artifacts) {
  $rel = [string]$artifact.path
  if ([string]::IsNullOrWhiteSpace($rel) -or $rel.Contains("..")) {
    $failures.Add("invalid artifact path: $rel")
    continue
  }
  $path = Join-Path $ResolvedSiteRoot ($rel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path)) {
    $failures.Add("missing artifact: $rel")
    continue
  }
  $item = Get-Item -LiteralPath $path
  $expectedBytes = [int64]$artifact.bytes
  if ($item.Length -ne $expectedBytes) {
    $failures.Add("size mismatch: $rel expected=$expectedBytes got=$($item.Length)")
  }
  $expectedHash = ([string]$artifact.sha256).ToUpperInvariant()
  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToUpperInvariant()
  if ($actualHash -ne $expectedHash) {
    $failures.Add("sha256 mismatch: $rel expected=$expectedHash got=$actualHash")
  }
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Error $failure
  }
  throw "Release manifest verification failed with $($failures.Count) issue(s)"
}

Write-Host "release manifest verified: $ResolvedManifestPath"
Write-Host "artifacts verified: $($manifest.artifacts.Count)"

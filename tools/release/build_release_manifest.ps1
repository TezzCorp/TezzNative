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
  "download/sdk/tezz",
  "download/sdk/tezz.cmd",
  "download/sdk/tezz.ps1",
  "download/sdk/tezz.mod",
  "download/sdk/tezz.lock",
  "download/sdk/registry.tnx",
  "download/sdk/docs/BENCHMARKS.md",
  "download/sdk/docs/CONFORMANCE.md",
  "download/sdk/docs/C_ABI.md",
  "download/sdk/docs/DEVELOPER_EXPERIENCE.md",
  "download/sdk/docs/NATIVE_BACKEND.md",
  "download/sdk/docs/OPTIMIZATION_PLAN.md",
  "download/sdk/docs/PACKAGE_TRUST.md",
  "download/sdk/docs/PLATFORM_SUPPORT.md",
  "download/sdk/docs/PYTHON_BRIDGE.md",
  "download/sdk/docs/RELEASE_ENGINEERING.md",
  "download/sdk/docs/STABILITY.md",
  "download/sdk/docs/STDLIB_CORE.md",
  "download/sdk/docs/STDLIB_INVENTORY.md",
  "download/sdk/docs/TRUST_BASELINE.md",
  "download/sdk/bin/tezzc.exe",
  "download/sdk/bin/tezzc-windows-x64.exe",
  "download/sdk/bin/tezzc-linux-x64",
  "download/sdk/benchmarks/README.md",
  "download/sdk/benchmarks/run.ps1",
  "download/sdk/benchmarks/run.sh",
  "download/sdk/benchmarks/tezz/file_io.tn",
  "download/sdk/benchmarks/tezz/startup.tn",
  "download/sdk/benchmarks/tezz/string_scan.tn",
  "download/sdk/benchmarks/tezz/sum_loop.tn",
  "download/sdk/benchmarks/python/file_io.py",
  "download/sdk/benchmarks/python/startup.py",
  "download/sdk/benchmarks/python/string_scan.py",
  "download/sdk/benchmarks/python/sum_loop.py",
  "download/sdk/benchmarks/c/file_io.c",
  "download/sdk/benchmarks/c/startup.c",
  "download/sdk/benchmarks/c/string_scan.c",
  "download/sdk/benchmarks/c/sum_loop.c",
  "download/sdk/benchmarks/node/file_io.js",
  "download/sdk/benchmarks/node/startup.js",
  "download/sdk/benchmarks/node/string_scan.js",
  "download/sdk/benchmarks/node/sum_loop.js",
  "download/sdk/benchmarks/go/file_io.go",
  "download/sdk/benchmarks/go/startup.go",
  "download/sdk/benchmarks/go/string_scan.go",
  "download/sdk/benchmarks/go/sum_loop.go",
  "download/sdk/benchmarks/rust/file_io.rs",
  "download/sdk/benchmarks/rust/startup.rs",
  "download/sdk/benchmarks/rust/string_scan.rs",
  "download/sdk/benchmarks/rust/sum_loop.rs",
  "download/sdk/tests/conformance/README.md",
  "download/sdk/tests/conformance/run-abi.ps1",
  "download/sdk/tests/conformance/run-abi.sh",
  "download/sdk/tests/conformance/run.ps1",
  "download/sdk/tests/conformance/run.sh",
  "download/sdk/tests/conformance/run-dx.ps1",
  "download/sdk/tests/conformance/run-dx.sh",
  "download/sdk/tests/conformance/run-package-trust.ps1",
  "download/sdk/tests/conformance/run-package-trust.sh",
  "download/sdk/tests/conformance/run-python-bridge.ps1",
  "download/sdk/tests/conformance/run-python-bridge.sh",
  "download/sdk/tests/conformance/run-native-reliability.ps1",
  "download/sdk/tests/conformance/run-native-reliability.sh",
  "download/sdk/tests/conformance/run-native-smoke.ps1",
  "download/sdk/tests/conformance/run-native-smoke.sh",
  "download/sdk/tests/conformance/abi/starter_abi.tn",
  "download/sdk/tests/conformance/valid/integer_widths.tn",
  "download/sdk/tests/conformance/native/int_widths.tn",
  "download/sdk/tests/conformance/native/int_widths.stdout.txt",
  "download/sdk/tests/conformance/native/stdlib_collections_edges.tn",
  "download/sdk/tests/conformance/native/stdlib_collections_edges.stdout.txt",
  "download/sdk/tests/conformance/native/stdlib_math_edges.tn",
  "download/sdk/tests/conformance/native/stdlib_math_edges.stdout.txt",
  "download/sdk/tests/conformance/parser/valid/comments_and_literals.tn",
  "download/sdk/tests/conformance/parser/invalid/bad_indentation.tn",
  "download/sdk/tests/conformance/typecheck/valid/functions_and_returns.tn",
  "download/sdk/tests/conformance/typecheck/invalid/return_type_mismatch.tn",
  "download/sdk/tests/conformance/dx/diagnostics/actionable_unknown_name.tn",
  "download/sdk/tests/conformance/dx/diagnostics/wrong_arity_help.tn",
  "download/sdk/tests/conformance/dx/fmt/control_flow.input.tn",
  "download/sdk/tests/conformance/dx/fmt/control_flow.formatted.tn",
  "download/sdk/tests/conformance/dx/lint/unused_var.tn",
  "download/sdk/tests/conformance/dx/lint/shadowed_var.tn",
  "download/sdk/tests/conformance/dx/lint/suppress_unused_var.tn",
  "download/sdk/tests/conformance/python_bridge/hot_math.tn",
  "download/sdk/examples/dx/hello.tn",
  "download/sdk/examples/dx/cli_flags.tn",
  "download/sdk/examples/dx/file_read_write.tn",
  "download/sdk/examples/dx/http_request_parse.tn",
  "download/sdk/examples/dx/http_server_route_once.tn",
  "download/sdk/examples/dx/c_extern_call.tn",
  "download/sdk/examples/dx/native_build.tn",
  "download/sdk/examples/dx/tezzdb_small.tn",
  "download/sdk/lib/std.tn",
  "download/sdk/lib/io.tn",
  "download/sdk/lib/str.tn",
  "download/sdk/lib/math.tn",
  "download/sdk/lib/time.tn",
  "download/sdk/lib/vec.tn",
  "download/sdk/lib/arena.tn",
  "download/sdk/lib/net.tn",
  "download/sdk/tools/tezz.tn",
  "download/sdk/tools/tezz_lsp.tn",
  "download/sdk/tezznative-vscode/snippets/snippets.json"
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

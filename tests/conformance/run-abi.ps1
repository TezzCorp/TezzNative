param(
  [string]$Tezzc = "",
  [switch]$SkipVerify,
  [switch]$KeepArtifacts,
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($Tezzc)) {
  $localCompiler = Join-Path $repoRoot 'TezzNative-language\bin\tezzc.exe'
  if (Test-Path -LiteralPath $localCompiler) {
    $Tezzc = $localCompiler
  } else {
    $Tezzc = 'tezzc'
  }
}

$abiDir = Join-Path $PSScriptRoot 'abi'
$artifactRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-abi-' + [guid]::NewGuid().ToString('N'))
$failed = 0

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

function Invoke-Compiler {
  param([string[]]$CompilerArgs)

  try {
    $output = & $Tezzc @CompilerArgs 2>&1
    $exitCode = $LASTEXITCODE
  } catch {
    $output = @($_.Exception.Message)
    $exitCode = 127
  }

  [pscustomobject]@{
    ExitCode = $exitCode
    Output = $output
  }
}

function Write-TestOutput {
  param([object[]]$Output)

  if (-not $Output) {
    return
  }

  foreach ($line in $Output) {
    Write-Host "  $line"
  }
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )

  if ($Text.Contains($Needle)) {
    return $true
  }

  Write-Host "FAIL $Label missing snippet"
  Write-Host "  expected snippet: $Needle"
  return $false
}

try {
  foreach ($file in Get-ChildItem -LiteralPath $abiDir -Filter '*.tn' | Sort-Object Name) {
    $check = Invoke-Compiler -CompilerArgs @('check', $file.FullName)
    if ($check.ExitCode -ne 0) {
      Write-Host "FAIL abi/$($file.Name) check exit=$($check.ExitCode)"
      Write-TestOutput -Output $check.Output
      $failed++
      continue
    }

    $base = Join-Path $artifactRoot $file.BaseName
    $headerPath = $base + '.h'
    $dumpPath = $base + '.tnx'

    $cheader = Invoke-Compiler -CompilerArgs @('cheader', $file.FullName, $headerPath)
    if ($cheader.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $headerPath)) {
      Write-Host "FAIL abi/$($file.Name) cheader exit=$($cheader.ExitCode)"
      Write-TestOutput -Output $cheader.Output
      $failed++
      continue
    }

    $dump = Invoke-Compiler -CompilerArgs @('abidump', $file.FullName, $dumpPath)
    if ($dump.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $dumpPath)) {
      Write-Host "FAIL abi/$($file.Name) abidump exit=$($dump.ExitCode)"
      Write-TestOutput -Output $dump.Output
      $failed++
      continue
    }

    $verify = $null
    if (-not $SkipVerify) {
      $verify = Invoke-Compiler -CompilerArgs @('abiverify', $file.FullName, $dumpPath)
      if ($verify.ExitCode -ne 0) {
        Write-Host "FAIL abi/$($file.Name) abiverify exit=$($verify.ExitCode)"
        Write-TestOutput -Output $verify.Output
        $failed++
        continue
      }
    }

    $header = Get-Content -LiteralPath $headerPath -Raw
    $abi = Get-Content -LiteralPath $dumpPath -Raw
    $ok = $true

    $headerSnippets = @(
      'typedef struct AbiPair {',
      'int64_t left;',
      'int64_t right;',
      '_Static_assert(sizeof(AbiPair) == 16, "ABI size mismatch for AbiPair");',
      '_Static_assert(_Alignof(AbiPair) == 8, "ABI align mismatch for AbiPair");',
      'typedef struct AbiBuffer {',
      'uint8_t * data;',
      'int64_t len;',
      '_Static_assert(sizeof(AbiBuffer) == 16, "ABI size mismatch for AbiBuffer");',
      'typedef struct AbiPacket {',
      'uint8_t bytes[8];',
      '_Static_assert(sizeof(AbiPacket) == 16, "ABI size mismatch for AbiPacket");'
    )

    foreach ($snippet in $headerSnippets) {
      if (-not (Assert-Contains -Text $header -Needle $snippet -Label "abi/$($file.Name) cheader")) {
        $ok = $false
      }
    }

    $abiSnippets = @(
      '"name":"AbiPair","size":16,"align":8',
      '"name":"AbiBuffer","size":16,"align":8',
      '"name":"AbiPacket","size":16,"align":8',
      '"name":"abi_pair_sum","extern":true,"ret":"i64"',
      '"params":["ptr","elem":"struct","name":"AbiPair","i64"]',
      '"name":"abi_buffer_len","extern":true,"ret":"i64"',
      '"params":["struct","name":"AbiBuffer"]',
      '"name":"abi_packet_send","extern":true,"ret":"void"',
      '"params":["ptr","elem":"struct","name":"AbiPacket"]'
    )

    foreach ($snippet in $abiSnippets) {
      if (-not (Assert-Contains -Text $abi -Needle $snippet -Label "abi/$($file.Name) abidump")) {
        $ok = $false
      }
    }

    if (-not $ok) {
      $failed++
      continue
    }

    Write-Host "ABI_OK $($file.Name)"
    if ($VerboseOutput) {
      Write-TestOutput -Output $cheader.Output
      Write-TestOutput -Output $dump.Output
      if ($verify) {
        Write-TestOutput -Output $verify.Output
      }
    }
  }
} finally {
  if ($KeepArtifacts) {
    Write-Host "ABI artifacts: $artifactRoot"
  } elseif (Test-Path -LiteralPath $artifactRoot) {
    Remove-Item -Recurse -Force -LiteralPath $artifactRoot
  }
}

Write-Host "ABI_SUMMARY failed=$failed"
if ($failed -ne 0) {
  exit 1
}

exit 0

param(
  [string]$Tezzc = "",
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

$validDir = Join-Path $PSScriptRoot 'valid'
$invalidDir = Join-Path $PSScriptRoot 'invalid'
$diagnosticsDir = Join-Path $PSScriptRoot 'diagnostics'
$stdlibDir = Join-Path $PSScriptRoot 'stdlib'
$failed = 0

function Invoke-TezzCheck {
  param([string]$Path)

  try {
    $output = & $Tezzc check $Path 2>&1
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

foreach ($file in Get-ChildItem -LiteralPath $validDir -Filter '*.tn' | Sort-Object Name) {
  $result = Invoke-TezzCheck -Path $file.FullName
  if ($result.ExitCode -eq 0) {
    Write-Host "OK valid/$($file.Name)"
    if ($VerboseOutput) {
      Write-TestOutput -Output $result.Output
    }
    continue
  }

  Write-Host "FAIL valid/$($file.Name) exit=$($result.ExitCode)"
  Write-TestOutput -Output $result.Output
  $failed++
}

if (Test-Path -LiteralPath $stdlibDir) {
  foreach ($file in Get-ChildItem -LiteralPath $stdlibDir -Filter '*.tn' | Sort-Object Name) {
    $result = Invoke-TezzCheck -Path $file.FullName
    if ($result.ExitCode -eq 0) {
      Write-Host "OK stdlib/$($file.Name)"
      if ($VerboseOutput) {
        Write-TestOutput -Output $result.Output
      }
      continue
    }

    Write-Host "FAIL stdlib/$($file.Name) exit=$($result.ExitCode)"
    Write-TestOutput -Output $result.Output
    $failed++
  }
}

foreach ($file in Get-ChildItem -LiteralPath $invalidDir -Filter '*.tn' | Sort-Object Name) {
  $result = Invoke-TezzCheck -Path $file.FullName
  if ($result.ExitCode -ne 0) {
    $diagPath = Join-Path $diagnosticsDir ($file.BaseName + '.diag.txt')
    if (Test-Path -LiteralPath $diagPath) {
      $expected = (Get-Content -LiteralPath $diagPath -Raw).Trim()
      $actual = ($result.Output | Out-String).Trim()
      if ($actual -notlike "*$expected*") {
        Write-Host "FAIL invalid/$($file.Name) diagnostic mismatch"
        Write-Host "  expected snippet: $expected"
        Write-TestOutput -Output $result.Output
        $failed++
        continue
      }
      Write-Host "INVALID_OK $($file.Name) diagnostic=matched"
    } else {
      Write-Host "INVALID_OK $($file.Name)"
    }
    if ($VerboseOutput) {
      Write-TestOutput -Output $result.Output
    }
    continue
  }

  Write-Host "FAIL invalid/$($file.Name) unexpectedly passed"
  Write-TestOutput -Output $result.Output
  $failed++
}

Write-Host "CONFORMANCE_SUMMARY failed=$failed"
if ($failed -ne 0) {
  exit 1
}

exit 0

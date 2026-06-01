param(
  [string]$Tezzc = "",
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($Tezzc)) {
  $localCompiler = Join-Path $repoRoot 'TezzNative-language\bin\tezzc.exe'
  if (Test-Path -LiteralPath $localCompiler) {
    $Tezzc = $localCompiler
  } else {
    $Tezzc = 'tezzc'
  }
} elseif (Test-Path -LiteralPath $Tezzc) {
  $Tezzc = (Resolve-Path -LiteralPath $Tezzc).Path
}

$failed = 0
$passed = 0

$validSuites = @(
  @{ Name = 'stable-core'; Path = 'valid' },
  @{ Name = 'parser'; Path = 'parser/valid' },
  @{ Name = 'typecheck'; Path = 'typecheck/valid' },
  @{ Name = 'stdlib'; Path = 'stdlib' }
)

$invalidSuites = @(
  @{ Name = 'diagnostics'; Path = 'invalid'; Diagnostics = 'diagnostics' },
  @{ Name = 'parser'; Path = 'parser/invalid'; Diagnostics = 'diagnostics/parser' },
  @{ Name = 'typecheck'; Path = 'typecheck/invalid'; Diagnostics = 'diagnostics/typecheck' }
)

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

function Get-SuiteFiles {
  param([string]$RelativePath)

  $dir = Join-Path $PSScriptRoot ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $dir)) {
    return @()
  }
  return @(Get-ChildItem -LiteralPath $dir -Filter '*.tn' | Sort-Object Name)
}

function Get-DiagnosticPath {
  param(
    [string]$RelativeDiagnosticsDir,
    [string]$BaseName
  )

  if ([string]::IsNullOrWhiteSpace($RelativeDiagnosticsDir)) {
    return ''
  }
  $dir = Join-Path $PSScriptRoot ($RelativeDiagnosticsDir -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  return Join-Path $dir ($BaseName + '.diag.txt')
}

function Get-DisplayPath {
  param(
    [string]$SuiteName,
    [string]$SuitePath,
    [string]$FileName
  )

  $path = (($SuitePath.TrimEnd('/') + '/' + $FileName) -replace '\\', '/')
  if ($path.StartsWith($SuiteName + '/', [System.StringComparison]::Ordinal)) {
    return $path
  }
  return (($SuiteName + '/' + $path) -replace '\\', '/')
}

foreach ($suite in $validSuites) {
  foreach ($file in Get-SuiteFiles -RelativePath $suite.Path) {
    $display = Get-DisplayPath -SuiteName $suite.Name -SuitePath $suite.Path -FileName $file.Name
    $result = Invoke-TezzCheck -Path $file.FullName
    if ($result.ExitCode -eq 0) {
      Write-Host "OK $display"
      if ($VerboseOutput) {
        Write-TestOutput -Output $result.Output
      }
      $passed++
      continue
    }

    Write-Host "FAIL $display exit=$($result.ExitCode)"
    Write-TestOutput -Output $result.Output
    $failed++
  }
}

foreach ($suite in $invalidSuites) {
  foreach ($file in Get-SuiteFiles -RelativePath $suite.Path) {
    $display = Get-DisplayPath -SuiteName $suite.Name -SuitePath $suite.Path -FileName $file.Name
    $result = Invoke-TezzCheck -Path $file.FullName
    if ($result.ExitCode -ne 0) {
      $diagPath = Get-DiagnosticPath -RelativeDiagnosticsDir $suite.Diagnostics -BaseName $file.BaseName
      if ($diagPath -and (Test-Path -LiteralPath $diagPath)) {
        $expected = (Get-Content -LiteralPath $diagPath -Raw).Trim()
        $actual = (($result.Output | Out-String) -replace "`r", '').Trim()
        if (-not $actual.Contains($expected)) {
          Write-Host "FAIL $display diagnostic mismatch"
          Write-Host "  expected snippet: $expected"
          Write-TestOutput -Output $result.Output
          $failed++
          continue
        }
        Write-Host "INVALID_OK $display diagnostic=matched"
      } else {
        Write-Host "INVALID_OK $display"
      }
      if ($VerboseOutput) {
        Write-TestOutput -Output $result.Output
      }
      $passed++
      continue
    }

    Write-Host "FAIL $display unexpectedly passed"
    Write-TestOutput -Output $result.Output
    $failed++
  }
}

Write-Host "CONFORMANCE_SUMMARY passed=$passed failed=$failed"
if ($failed -ne 0) {
  exit 1
}

exit 0

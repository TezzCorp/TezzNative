param(
  [string]$Tezzc = "",
  [string]$Target = "",
  [switch]$CheckOnly,
  [switch]$CheckIrOnly,
  [switch]$BuildOnly,
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

$smokeDir = Join-Path $PSScriptRoot 'native'
$artifactRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-native-smoke-' + [guid]::NewGuid().ToString('N'))
$isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
  [System.Runtime.InteropServices.OSPlatform]::Windows
)
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

function Normalize-Output {
  param([object[]]$Output)

  if (-not $Output) {
    return ''
  }

  (($Output | Out-String) -replace "`r`n", "`n").TrimEnd("`n")
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

try {
  foreach ($file in Get-ChildItem -LiteralPath $smokeDir -Filter '*.tn' | Sort-Object Name) {
    $check = Invoke-Compiler -CompilerArgs @('check', $file.FullName)
    if ($check.ExitCode -ne 0) {
      Write-Host "FAIL native/$($file.Name) check exit=$($check.ExitCode)"
      Write-TestOutput -Output $check.Output
      $failed++
      continue
    }

    if ($CheckOnly) {
      Write-Host "NATIVE_CHECK_OK $($file.Name)"
      if ($VerboseOutput) {
        Write-TestOutput -Output $check.Output
      }
      continue
    }

    if ($CheckIrOnly) {
      $ir = Invoke-Compiler -CompilerArgs @('ir', $file.FullName, '--repro')
      if ($ir.ExitCode -ne 0) {
        Write-Host "FAIL native/$($file.Name) ir exit=$($ir.ExitCode)"
        Write-TestOutput -Output $ir.Output
        $failed++
        continue
      }

      Write-Host "NATIVE_IR_OK $($file.Name)"
      if ($VerboseOutput) {
        Write-TestOutput -Output $ir.Output
      }
      continue
    }

    $exeName = $file.BaseName
    if ($isWindows) {
      $exeName += '.exe'
    }
    $exePath = Join-Path $artifactRoot $exeName
    $buildArgs = @('buildexe', $file.FullName, $exePath, '--verify')
    if (-not [string]::IsNullOrWhiteSpace($Target)) {
      $buildArgs += @('--target', $Target)
    }

    $build = Invoke-Compiler -CompilerArgs $buildArgs
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
      Write-Host "FAIL native/$($file.Name) build exit=$($build.ExitCode)"
      Write-TestOutput -Output $build.Output
      $failed++
      continue
    }

    if ($BuildOnly) {
      Write-Host "NATIVE_BUILD_OK $($file.Name)"
      if ($VerboseOutput) {
        Write-TestOutput -Output $build.Output
      }
      continue
    }

    $runOutput = & $exePath 2>&1
    $runExit = $LASTEXITCODE
    if ($runExit -ne 0) {
      Write-Host "FAIL native/$($file.Name) run exit=$runExit"
      Write-TestOutput -Output $runOutput
      $failed++
      continue
    }

    $stdoutPath = Join-Path $smokeDir ($file.BaseName + '.stdout.txt')
    if (Test-Path -LiteralPath $stdoutPath) {
      $expected = ((Get-Content -LiteralPath $stdoutPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
      $actual = Normalize-Output -Output $runOutput
      if ($actual -ne $expected) {
        Write-Host "FAIL native/$($file.Name) stdout mismatch"
        Write-Host "  expected: $expected"
        Write-Host "  actual:   $actual"
        $failed++
        continue
      }
    }

    Write-Host "NATIVE_OK $($file.Name)"
    if ($VerboseOutput) {
      Write-TestOutput -Output $build.Output
      Write-TestOutput -Output $runOutput
    }
  }
} finally {
  if ($KeepArtifacts) {
    Write-Host "native smoke artifacts: $artifactRoot"
  } elseif (Test-Path -LiteralPath $artifactRoot) {
    Remove-Item -Recurse -Force -LiteralPath $artifactRoot
  }
}

Write-Host "NATIVE_SMOKE_SUMMARY failed=$failed"
if ($failed -ne 0) {
  exit 1
}

exit 0

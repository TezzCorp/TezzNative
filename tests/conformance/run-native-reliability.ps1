param(
  [string]$Tezzc = "",
  [string]$Target = "",
  [int]$Iterations = 2,
  [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'

if ($Iterations -lt 2) {
  throw "Iterations must be at least 2"
}

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($Tezzc)) {
  $localCompiler = Join-Path $repoRoot 'TezzNative-language\bin\tezzc.exe'
  if (Test-Path -LiteralPath $localCompiler) {
    $Tezzc = $localCompiler
  } else {
    $Tezzc = 'tezzc'
  }
}

$isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
  [System.Runtime.InteropServices.OSPlatform]::Windows
)
if ([string]::IsNullOrWhiteSpace($Target)) {
  $Target = if ($isWindows) { 'x86_64' } else { 'linux' }
}

$nativeDir = Join-Path $PSScriptRoot 'native'
$artifactRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-native-reliability-' + [guid]::NewGuid().ToString('N'))
$fixtures = @(
  'hello.tn',
  'loop_math.tn',
  'many_args.tn',
  'many_args_nested.tn',
  'many_args_strings.tn',
  'math_module.tn',
  'string_ops.tn',
  'string_transforms.tn',
  'struct_array.tn',
  'collections_memory.tn'
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

function Test-ExecutableForTarget {
  param([string]$TargetName)

  if ($isWindows) {
    return ($TargetName -in @('x86_64', 'x64', 'amd64', 'native', 'x86'))
  }
  return ($TargetName -in @('linux', 'elf'))
}

try {
  $status = Invoke-Compiler -CompilerArgs @('buildexe', '--status')
  $statusText = Normalize-Output -Output $status.Output
  if ($status.ExitCode -ne 0 -or $statusText -notmatch 'Windows' -or $statusText -notmatch 'Linux') {
    Write-Host "FAIL native-reliability buildexe-status exit=$($status.ExitCode)"
    Write-TestOutput -Output $status.Output
    $failed++
  } else {
    Write-Host "NATIVE_RELIABILITY_STATUS_OK"
  }

  foreach ($fixture in $fixtures) {
    $source = Join-Path $nativeDir $fixture
    if (-not (Test-Path -LiteralPath $source)) {
      Write-Host "FAIL native-reliability/$fixture missing"
      $failed++
      continue
    }

    $hashes = @()
    $firstExe = ''
    for ($i = 1; $i -le $Iterations; $i++) {
      $exeName = [System.IO.Path]::GetFileNameWithoutExtension($fixture) + "-$i"
      if ($isWindows -and (Test-ExecutableForTarget -TargetName $Target)) {
        $exeName += '.exe'
      }
      $exePath = Join-Path $artifactRoot $exeName
      $build = Invoke-Compiler -CompilerArgs @('buildexe', $source, $exePath, '--target', $Target, '--verify')
      if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        Write-Host "FAIL native-reliability/$fixture build iteration=$i exit=$($build.ExitCode)"
        Write-TestOutput -Output $build.Output
        $failed++
        continue
      }

      if ([string]::IsNullOrWhiteSpace($firstExe)) {
        $firstExe = $exePath
      }
      $hashes += (Get-FileHash -Algorithm SHA256 -LiteralPath $exePath).Hash.ToUpperInvariant()
    }

    if ($hashes.Count -eq $Iterations) {
      $uniqueHashes = @($hashes | Sort-Object -Unique)
      if ($uniqueHashes.Count -ne 1) {
        Write-Host "FAIL native-reliability/$fixture reproducible hashes=$($uniqueHashes -join ',')"
        $failed++
        continue
      }

      if (Test-ExecutableForTarget -TargetName $Target) {
        Push-Location -LiteralPath $artifactRoot
        try {
          $runOutput = & $firstExe 2>&1
          $runExit = $LASTEXITCODE
        } finally {
          Pop-Location
        }
        if ($runExit -ne 0) {
          Write-Host "FAIL native-reliability/$fixture run exit=$runExit"
          Write-TestOutput -Output $runOutput
          $failed++
          continue
        }

        $stdoutPath = Join-Path $nativeDir ([System.IO.Path]::GetFileNameWithoutExtension($fixture) + '.stdout.txt')
        if (Test-Path -LiteralPath $stdoutPath) {
          $expected = ((Get-Content -LiteralPath $stdoutPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
          $actual = Normalize-Output -Output $runOutput
          if ($actual -ne $expected) {
            Write-Host "FAIL native-reliability/$fixture stdout mismatch"
            Write-Host "  expected: $expected"
            Write-Host "  actual:   $actual"
            $failed++
            continue
          }
        }
      }

      Write-Host "NATIVE_REPRO_OK $fixture target=$Target sha256=$($uniqueHashes[0])"
    }
  }

  $badOut = Join-Path $artifactRoot 'unsupported-target.bin'
  $bad = Invoke-Compiler -CompilerArgs @('buildexe', (Join-Path $nativeDir 'hello.tn'), $badOut, '--target', 'tezznative-unsupported-target')
  $badText = Normalize-Output -Output $bad.Output
  if ($bad.ExitCode -eq 0 -or (Test-Path -LiteralPath $badOut) -or $badText -notmatch 'unsupported target') {
    Write-Host "FAIL native-reliability unsupported-target exit=$($bad.ExitCode)"
    Write-TestOutput -Output $bad.Output
    $failed++
  } else {
    Write-Host "NATIVE_UNSUPPORTED_TARGET_OK"
  }
} finally {
  if ($KeepArtifacts) {
    Write-Host "native reliability artifacts: $artifactRoot"
  } elseif (Test-Path -LiteralPath $artifactRoot) {
    Remove-Item -Recurse -Force -LiteralPath $artifactRoot
  }
}

Write-Host "NATIVE_RELIABILITY_SUMMARY failed=$failed"
if ($failed -ne 0) {
  exit 1
}

exit 0

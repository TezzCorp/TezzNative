param(
  [string]$Tezzc = "",
  [int]$Iterations = 3,
  [string]$OutPath = "",
  [switch]$CheckOnly,
  [switch]$IncludeExternal,
  [switch]$SkipNative,
  [switch]$RequireNative
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
if ([string]::IsNullOrWhiteSpace($Tezzc)) {
  $localCompiler = Join-Path $root 'TezzNative-language\bin\tezzc.exe'
  if (Test-Path -LiteralPath $localCompiler) {
    $Tezzc = $localCompiler
  } else {
    $Tezzc = 'tezzc'
  }
} elseif (Test-Path -LiteralPath $Tezzc) {
  $Tezzc = (Resolve-Path -LiteralPath $Tezzc).Path
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $OutPath = Join-Path $PSScriptRoot 'results\latest.csv'
}

$resultDir = Split-Path -Parent $OutPath
if (-not [string]::IsNullOrWhiteSpace($resultDir)) {
  New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-bench-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$results = New-Object System.Collections.Generic.List[object]
$failed = 0

function Invoke-Measured {
  param(
    [string]$File,
    [string[]]$CommandArgs,
    [string]$WorkingDirectory = ""
  )

  $previous = Get-Location
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    Set-Location -LiteralPath $WorkingDirectory
  }

  try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $output = & $File @CommandArgs 2>&1
      $exitCode = $LASTEXITCODE
    } catch {
      $output = @($_.Exception.Message)
      $exitCode = 127
    }
    $sw.Stop()
  } finally {
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
      Set-Location $previous
    }
  }

  [pscustomobject]@{
    ExitCode = $exitCode
    ElapsedMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 3)
    Output = $output
  }
}

function Add-Result {
  param(
    [string]$Bench,
    [string]$Language,
    [string]$Mode,
    [string]$Phase,
    [int]$Iteration,
    [double]$ElapsedMs,
    [int64]$Bytes,
    [int]$ExitCode,
    [string]$Command
  )

  $results.Add([pscustomobject]@{
    timestamp_utc = [DateTime]::UtcNow.ToString('o')
    os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    powershell = $PSVersionTable.PSVersion.ToString()
    bench = $Bench
    language = $Language
    mode = $Mode
    phase = $Phase
    iteration = $Iteration
    elapsed_ms = $ElapsedMs
    bytes = $Bytes
    exit_code = $ExitCode
    command = $Command
  })
}

function Get-ExeName {
  param([string]$Name)

  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows)) {
    return "$Name.exe"
  }
  return $Name
}

try {
  $tezzFiles = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tezz') -Filter '*.tn' | Sort-Object Name
  foreach ($file in $tezzFiles) {
    $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $check = Invoke-Measured -File $Tezzc -CommandArgs @('check', $file.FullName)
    Add-Result -Bench $bench -Language 'tezznative' -Mode 'check' -Phase 'check' -Iteration 0 -ElapsedMs $check.ElapsedMs -Bytes 0 -ExitCode $check.ExitCode -Command "$Tezzc check $($file.FullName)"
    if ($check.ExitCode -ne 0) {
      Write-Host "FAIL benchmark/$($file.Name) check exit=$($check.ExitCode)"
      foreach ($line in $check.Output) {
        Write-Host "  $line"
      }
      $failed++
      continue
    }

    Write-Host "BENCH_CHECK_OK $($file.Name)"
    if ($CheckOnly) {
      continue
    }

    for ($i = 1; $i -le $Iterations; $i++) {
      $run = Invoke-Measured -File $Tezzc -CommandArgs @('run', $file.FullName, '--bc')
      Add-Result -Bench $bench -Language 'tezznative' -Mode 'bytecode' -Phase 'run' -Iteration $i -ElapsedMs $run.ElapsedMs -Bytes 0 -ExitCode $run.ExitCode -Command "$Tezzc run $($file.FullName) --bc"
      if ($run.ExitCode -ne 0) {
        Write-Host "FAIL benchmark/$($file.Name) bytecode exit=$($run.ExitCode)"
        $failed++
        break
      }
    }

    if (-not $SkipNative) {
      $exePath = Join-Path $workDir (Get-ExeName -Name $bench)
      $build = Invoke-Measured -File $Tezzc -CommandArgs @('buildexe', $file.FullName, $exePath, '--verify')
      $bytes = 0
      if (Test-Path -LiteralPath $exePath) {
        $bytes = (Get-Item -LiteralPath $exePath).Length
      }
      Add-Result -Bench $bench -Language 'tezznative' -Mode 'native' -Phase 'build' -Iteration 0 -ElapsedMs $build.ElapsedMs -Bytes $bytes -ExitCode $build.ExitCode -Command "$Tezzc buildexe $($file.FullName) $exePath --verify"
      if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        Write-Host "WARN benchmark/$($file.Name) native build unavailable exit=$($build.ExitCode)"
        if ($RequireNative) {
          $failed++
        }
      } else {
        for ($i = 1; $i -le $Iterations; $i++) {
          $native = Invoke-Measured -File $exePath -CommandArgs @()
          Add-Result -Bench $bench -Language 'tezznative' -Mode 'native' -Phase 'run' -Iteration $i -ElapsedMs $native.ElapsedMs -Bytes $bytes -ExitCode $native.ExitCode -Command $exePath
          if ($native.ExitCode -ne 0) {
            Write-Host "FAIL benchmark/$($file.Name) native exit=$($native.ExitCode)"
            $failed++
            break
          }
        }
      }
    }
  }

  if ($IncludeExternal -and -not $CheckOnly) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) {
      $python = Get-Command python -ErrorAction SilentlyContinue
    }
    if ($python) {
      foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'python') -Filter '*.py' | Sort-Object Name) {
        $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        for ($i = 1; $i -le $Iterations; $i++) {
          $run = Invoke-Measured -File $python.Source -CommandArgs @($file.FullName)
          Add-Result -Bench $bench -Language 'python' -Mode 'interpreter' -Phase 'run' -Iteration $i -ElapsedMs $run.ElapsedMs -Bytes 0 -ExitCode $run.ExitCode -Command "$($python.Source) $($file.FullName)"
          if ($run.ExitCode -ne 0) {
            Write-Host "WARN benchmark/$($file.Name) python exit=$($run.ExitCode)"
            break
          }
        }
      }
    } else {
      Write-Host 'SKIP python benchmarks: python3/python not found'
    }

    $cc = Get-Command gcc -ErrorAction SilentlyContinue
    if (-not $cc) {
      $cc = Get-Command clang -ErrorAction SilentlyContinue
    }
    if ($cc) {
      foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'c') -Filter '*.c' | Sort-Object Name) {
        $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $exePath = Join-Path $workDir (Get-ExeName -Name "$bench-c")
        $compile = Invoke-Measured -File $cc.Source -CommandArgs @('-O3', '-std=c11', $file.FullName, '-o', $exePath)
        $bytes = 0
        if (Test-Path -LiteralPath $exePath) {
          $bytes = (Get-Item -LiteralPath $exePath).Length
        }
        Add-Result -Bench $bench -Language 'c' -Mode 'native' -Phase 'build' -Iteration 0 -ElapsedMs $compile.ElapsedMs -Bytes $bytes -ExitCode $compile.ExitCode -Command "$($cc.Source) -O3 -std=c11 $($file.FullName) -o $exePath"
        if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
          Write-Host "WARN benchmark/$($file.Name) C build unavailable exit=$($compile.ExitCode)"
          continue
        }
        for ($i = 1; $i -le $Iterations; $i++) {
          $run = Invoke-Measured -File $exePath -CommandArgs @()
          Add-Result -Bench $bench -Language 'c' -Mode 'native' -Phase 'run' -Iteration $i -ElapsedMs $run.ElapsedMs -Bytes $bytes -ExitCode $run.ExitCode -Command $exePath
          if ($run.ExitCode -ne 0) {
            Write-Host "WARN benchmark/$($file.Name) C native exit=$($run.ExitCode)"
            break
          }
        }
      }
    } else {
      Write-Host 'SKIP C benchmarks: gcc/clang not found'
    }
  }
} finally {
  if (Test-Path -LiteralPath $workDir) {
    Remove-Item -Recurse -Force -LiteralPath $workDir
  }
}

$results | Export-Csv -Path $OutPath -NoTypeInformation -Encoding UTF8
Write-Host "BENCH_RESULTS $OutPath"

if ($failed -ne 0) {
  exit 1
}

exit 0

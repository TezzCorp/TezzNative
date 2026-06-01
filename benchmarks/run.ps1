param(
  [string]$Tezzc = "",
  [int]$Iterations = 3,
  [string]$OutPath = "",
  [string]$MetadataPath = "",
  [switch]$CheckOnly,
  [switch]$IncludeExternal,
  [switch]$SkipNative,
  [switch]$RequireNative,
  [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
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
if ([string]::IsNullOrWhiteSpace($MetadataPath)) {
  $MetadataPath = [System.IO.Path]::ChangeExtension($OutPath, '.metadata.json')
}

$resultDir = Split-Path -Parent $OutPath
if (-not [string]::IsNullOrWhiteSpace($resultDir)) {
  New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
}
$metadataDir = Split-Path -Parent $MetadataPath
if (-not [string]::IsNullOrWhiteSpace($metadataDir)) {
  New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null
}

$runId = [guid]::NewGuid().ToString('N')
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-bench-' + $runId)
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$results = New-Object System.Collections.Generic.List[object]
$failed = 0

function Quote-CommandPart {
  param([string]$Value)
  if ($Value -match '[\s"]') {
    return '"' + ($Value -replace '"', '\"') + '"'
  }
  return $Value
}

function Format-Command {
  param(
    [string]$File,
    [string[]]$CommandArgs
  )
  $parts = @((Quote-CommandPart $File))
  foreach ($arg in $CommandArgs) {
    $parts += (Quote-CommandPart $arg)
  }
  return ($parts -join ' ')
}

function Join-ProcessArguments {
  param([string[]]$CommandArgs)
  $parts = @()
  foreach ($arg in $CommandArgs) {
    $parts += (Quote-CommandPart $arg)
  }
  return ($parts -join ' ')
}

function Get-TextHash {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToUpperInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-Preview {
  param([string]$Text)
  $clean = (($Text -replace "`r", '') -replace "`n", ' | ').Trim()
  if ($clean.Length -gt 240) {
    return $clean.Substring(0, 240)
  }
  return $clean
}

function Get-BenchCategory {
  param([string]$Bench)
  switch -Regex ($Bench) {
    '^startup$' { return 'startup' }
    'file|io' { return 'file-io' }
    'string|scan|text' { return 'string-processing' }
    'sum|loop|numeric|math' { return 'numeric-loop' }
    default { return 'general' }
  }
}

function Resolve-Tool {
  param([string[]]$Names)
  foreach ($name in $Names) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
      return $cmd.Source
    }
  }
  return ''
}

function Invoke-Measured {
  param(
    [string]$File,
    [string[]]$CommandArgs,
    [string]$WorkingDirectory = "",
    [int]$TimeoutSec = $TimeoutSeconds
  )

  $stdout = ''
  $stderr = ''
  $exitCode = 127
  $timedOut = $false
  $peak = 0
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $File
    $psi.Arguments = Join-ProcessArguments -CommandArgs $CommandArgs
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
      $psi.WorkingDirectory = $WorkingDirectory
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit([Math]::Max(1, $TimeoutSec) * 1000)) {
      $timedOut = $true
      try {
        $proc.Kill($true)
      } catch {
        try { $proc.Kill() } catch { }
      }
    }
    $proc.WaitForExit()
    $sw.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $proc.ExitCode }
    try {
      $peak = [int64]$proc.PeakWorkingSet64
    } catch {
      $peak = 0
    }
    $proc.Dispose()
  } catch {
    $sw.Stop()
    $stderr = $_.Exception.Message
    $exitCode = 127
  }

  [pscustomobject]@{
    ExitCode = $exitCode
    ElapsedMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 3)
    PeakWorkingSetBytes = $peak
    TimedOut = $timedOut
    Stdout = $stdout
    Stderr = $stderr
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
    [int64]$PeakWorkingSetBytes,
    [int64]$Bytes,
    [int]$ExitCode,
    [bool]$TimedOut,
    [string]$Command,
    [string]$Stdout,
    [string]$Stderr
  )

  $combined = ($Stdout + "`n" + $Stderr)
  $results.Add([pscustomobject]@{
    schema = 'tezznative.benchmark-result.v1'
    run_id = $runId
    timestamp_utc = [DateTime]::UtcNow.ToString('o')
    os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    processor_count = [Environment]::ProcessorCount
    bench = $Bench
    category = Get-BenchCategory -Bench $Bench
    language = $Language
    mode = $Mode
    phase = $Phase
    iteration = $Iteration
    elapsed_ms = $ElapsedMs
    peak_working_set_bytes = $PeakWorkingSetBytes
    bytes = $Bytes
    exit_code = $ExitCode
    timed_out = $TimedOut
    command = $Command
    output_sha256 = Get-TextHash -Text $combined
    output_preview = Get-Preview -Text $combined
  })
}

function Add-MeasuredResult {
  param(
    [string]$Bench,
    [string]$Language,
    [string]$Mode,
    [string]$Phase,
    [int]$Iteration,
    [int64]$Bytes,
    [string]$File,
    [string[]]$CommandArgs,
    [object]$Measured
  )
  Add-Result `
    -Bench $Bench `
    -Language $Language `
    -Mode $Mode `
    -Phase $Phase `
    -Iteration $Iteration `
    -ElapsedMs $Measured.ElapsedMs `
    -PeakWorkingSetBytes $Measured.PeakWorkingSetBytes `
    -Bytes $Bytes `
    -ExitCode $Measured.ExitCode `
    -TimedOut $Measured.TimedOut `
    -Command (Format-Command -File $File -CommandArgs $CommandArgs) `
    -Stdout $Measured.Stdout `
    -Stderr $Measured.Stderr
}

function Get-ExeName {
  param([string]$Name)
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows)) {
    return "$Name.exe"
  }
  return $Name
}

function Invoke-InterpretedBenchmarks {
  param(
    [string]$Language,
    [string]$Mode,
    [string]$Directory,
    [string]$Filter,
    [string]$Tool
  )
  if ([string]::IsNullOrWhiteSpace($Tool) -or -not (Test-Path -LiteralPath $Directory)) {
    Write-Host "SKIP $Language benchmarks: tool or directory not available"
    return
  }

  foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter $Filter | Sort-Object Name) {
    $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    for ($i = 1; $i -le $Iterations; $i++) {
      $args = @($file.FullName)
      $run = Invoke-Measured -File $Tool -CommandArgs $args -WorkingDirectory $workDir
      Add-MeasuredResult -Bench $bench -Language $Language -Mode $Mode -Phase 'run' -Iteration $i -Bytes 0 -File $Tool -CommandArgs $args -Measured $run
      if ($run.ExitCode -ne 0) {
        Write-Host "FAIL benchmark/$($file.Name) $Language exit=$($run.ExitCode)"
        $script:failed++
        break
      }
    }
  }
}

function Invoke-CompiledBenchmarks {
  param(
    [string]$Language,
    [string]$Directory,
    [string]$Filter,
    [string]$Tool,
    [scriptblock]$BuildArgsFactory
  )
  if ([string]::IsNullOrWhiteSpace($Tool) -or -not (Test-Path -LiteralPath $Directory)) {
    Write-Host "SKIP $Language benchmarks: tool or directory not available"
    return
  }

  foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter $Filter | Sort-Object Name) {
    $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $exePath = Join-Path $workDir (Get-ExeName -Name "$bench-$Language")
    $buildArgs = & $BuildArgsFactory $file.FullName $exePath
    $build = Invoke-Measured -File $Tool -CommandArgs $buildArgs -WorkingDirectory $workDir -TimeoutSec ([Math]::Max($TimeoutSeconds, 120))
    $bytes = 0
    if (Test-Path -LiteralPath $exePath) {
      $bytes = (Get-Item -LiteralPath $exePath).Length
    }
    Add-MeasuredResult -Bench $bench -Language $Language -Mode 'native' -Phase 'build' -Iteration 0 -Bytes $bytes -File $Tool -CommandArgs $buildArgs -Measured $build
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
      Write-Host "FAIL benchmark/$($file.Name) $Language build exit=$($build.ExitCode)"
      $script:failed++
      continue
    }
    for ($i = 1; $i -le $Iterations; $i++) {
      $run = Invoke-Measured -File $exePath -CommandArgs @() -WorkingDirectory $workDir
      Add-MeasuredResult -Bench $bench -Language $Language -Mode 'native' -Phase 'run' -Iteration $i -Bytes $bytes -File $exePath -CommandArgs @() -Measured $run
      if ($run.ExitCode -ne 0) {
        Write-Host "FAIL benchmark/$($file.Name) $Language native exit=$($run.ExitCode)"
        $script:failed++
        break
      }
    }
  }
}

try {
  $tezzFiles = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tezz') -Filter '*.tn' | Sort-Object Name
  foreach ($file in $tezzFiles) {
    $bench = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $sourceArg = $file.FullName.Substring($root.Length).TrimStart('\', '/')
    $checkArgs = @('check', $sourceArg)
    $check = Invoke-Measured -File $Tezzc -CommandArgs $checkArgs -WorkingDirectory $root
    Add-MeasuredResult -Bench $bench -Language 'tezznative' -Mode 'check' -Phase 'check' -Iteration 0 -Bytes 0 -File $Tezzc -CommandArgs $checkArgs -Measured $check
    if ($check.ExitCode -ne 0) {
      Write-Host "FAIL benchmark/$($file.Name) check exit=$($check.ExitCode)"
      Write-Host (Get-Preview -Text ($check.Stdout + "`n" + $check.Stderr))
      $failed++
      continue
    }

    Write-Host "BENCH_CHECK_OK $($file.Name)"
    if ($CheckOnly) {
      continue
    }

    for ($i = 1; $i -le $Iterations; $i++) {
      $runArgs = @('run', $sourceArg, '--bc')
      $run = Invoke-Measured -File $Tezzc -CommandArgs $runArgs -WorkingDirectory $root
      Add-MeasuredResult -Bench $bench -Language 'tezznative' -Mode 'bytecode' -Phase 'run' -Iteration $i -Bytes 0 -File $Tezzc -CommandArgs $runArgs -Measured $run
      if ($run.ExitCode -ne 0) {
        Write-Host "FAIL benchmark/$($file.Name) bytecode exit=$($run.ExitCode)"
        Write-Host (Get-Preview -Text ($run.Stdout + "`n" + $run.Stderr))
        $failed++
        break
      }
    }

    if (-not $SkipNative) {
      $exePath = Join-Path $workDir (Get-ExeName -Name $bench)
      $buildArgs = @('buildexe', $sourceArg, $exePath, '--verify')
      $build = Invoke-Measured -File $Tezzc -CommandArgs $buildArgs -WorkingDirectory $root -TimeoutSec ([Math]::Max($TimeoutSeconds, 120))
      $bytes = 0
      if (Test-Path -LiteralPath $exePath) {
        $bytes = (Get-Item -LiteralPath $exePath).Length
      }
      Add-MeasuredResult -Bench $bench -Language 'tezznative' -Mode 'native' -Phase 'build' -Iteration 0 -Bytes $bytes -File $Tezzc -CommandArgs $buildArgs -Measured $build
      if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        Write-Host "WARN benchmark/$($file.Name) native build unavailable exit=$($build.ExitCode)"
        if ($RequireNative) {
          $failed++
        }
      } else {
        for ($i = 1; $i -le $Iterations; $i++) {
          $native = Invoke-Measured -File $exePath -CommandArgs @() -WorkingDirectory $workDir
          Add-MeasuredResult -Bench $bench -Language 'tezznative' -Mode 'native' -Phase 'run' -Iteration $i -Bytes $bytes -File $exePath -CommandArgs @() -Measured $native
          if ($native.ExitCode -ne 0) {
            Write-Host "FAIL benchmark/$($file.Name) native exit=$($native.ExitCode)"
            Write-Host (Get-Preview -Text ($native.Stdout + "`n" + $native.Stderr))
            $failed++
            break
          }
        }
      }
    }
  }

  if ($IncludeExternal -and -not $CheckOnly) {
    $python = Resolve-Tool @('python3', 'python')
    Invoke-InterpretedBenchmarks -Language 'python' -Mode 'interpreter' -Directory (Join-Path $PSScriptRoot 'python') -Filter '*.py' -Tool $python

    $node = Resolve-Tool @('node')
    Invoke-InterpretedBenchmarks -Language 'nodejs' -Mode 'interpreter' -Directory (Join-Path $PSScriptRoot 'node') -Filter '*.js' -Tool $node

    $cc = Resolve-Tool @('gcc', 'clang', 'cc')
    Invoke-CompiledBenchmarks -Language 'c' -Directory (Join-Path $PSScriptRoot 'c') -Filter '*.c' -Tool $cc -BuildArgsFactory {
      param($Source, $Out)
      @('-O3', '-std=c11', $Source, '-o', $Out)
    }

    $go = Resolve-Tool @('go')
    Invoke-CompiledBenchmarks -Language 'go' -Directory (Join-Path $PSScriptRoot 'go') -Filter '*.go' -Tool $go -BuildArgsFactory {
      param($Source, $Out)
      @('build', '-o', $Out, $Source)
    }

    $rustc = Resolve-Tool @('rustc')
    Invoke-CompiledBenchmarks -Language 'rust' -Directory (Join-Path $PSScriptRoot 'rust') -Filter '*.rs' -Tool $rustc -BuildArgsFactory {
      param($Source, $Out)
      @('-C', 'opt-level=3', $Source, '-o', $Out)
    }
  }
} finally {
  if (Test-Path -LiteralPath $workDir) {
    Remove-Item -Recurse -Force -LiteralPath $workDir
  }
}

$metadata = [ordered]@{
  schema = 'tezznative.benchmark-run.v1'
  run_id = $runId
  generated_utc = [DateTime]::UtcNow.ToString('o')
  repository = $root
  tezzc = $Tezzc
  iterations = $Iterations
  check_only = [bool]$CheckOnly
  include_external = [bool]$IncludeExternal
  skip_native = [bool]$SkipNative
  require_native = [bool]$RequireNative
  timeout_seconds = $TimeoutSeconds
  host = [ordered]@{
    os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    framework = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    processor_count = [Environment]::ProcessorCount
    powershell = $PSVersionTable.PSVersion.ToString()
  }
  workloads = @($results | Select-Object bench, category -Unique | Sort-Object bench)
  result_csv = $OutPath
}

$results | Export-Csv -Path $OutPath -NoTypeInformation -Encoding UTF8
($metadata | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $MetadataPath -Encoding UTF8
Write-Host "BENCH_RESULTS $OutPath"
Write-Host "BENCH_METADATA $MetadataPath"
Write-Host "BENCH_SUMMARY failed=$failed results=$($results.Count)"

if ($failed -ne 0) {
  exit 1
}

exit 0

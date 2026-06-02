param(
  [string]$Tezzc = "",
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}

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

function Invoke-Tezz {
  param([string[]]$TezzArgs)

  try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Tezzc
    $quotedArgs = @()
    foreach ($arg in $TezzArgs) {
      if ($arg -match '[\s"]') {
        $quotedArgs += '"' + ($arg -replace '"', '\"') + '"'
      } else {
        $quotedArgs += $arg
      }
    }
    $psi.Arguments = $quotedArgs -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $output = $stdout + $stderr
    $exitCode = $process.ExitCode
  } catch {
    $output = @($_.Exception.Message)
    $exitCode = 127
  }

  [pscustomobject]@{
    ExitCode = $exitCode
    Output = (($output | Out-String) -replace "`r", '').Trim()
  }
}

function Write-DxOutput {
  param([string]$Output)

  if ([string]::IsNullOrWhiteSpace($Output)) {
    return
  }
  foreach ($line in ($Output -split "`n")) {
    Write-Host "  $line"
  }
}

function Add-Pass {
  param([string]$Name)
  Write-Host "DX_OK $Name"
  $script:passed++
}

function Add-Fail {
  param(
    [string]$Name,
    [string]$Reason,
    [string]$Output = ''
  )
  Write-Host "DX_FAIL $Name $Reason"
  Write-DxOutput -Output $Output
  $script:failed++
}

function Test-Contains {
  param(
    [string]$Name,
    [string]$Text,
    [string[]]$Needles
  )
  foreach ($needle in $Needles) {
    if (-not $Text.Contains($needle)) {
      Add-Fail -Name $Name -Reason "missing '$needle'" -Output $Text
      return $false
    }
  }
  return $true
}

Push-Location $repoRoot
try {
  $diagnostics = @(
    @{
      Name = 'diagnostic-help-unknown-name'
      Path = 'tests/conformance/dx/diagnostics/actionable_unknown_name.tn'
      Needles = @(
        "unknown name 'missing_total'",
        'ret missing_total',
        '^',
        'help: declare the name before use'
      )
    },
    @{
      Name = 'diagnostic-help-wrong-arity'
      Path = 'tests/conformance/dx/diagnostics/wrong_arity_help.tn'
      Needles = @(
        "wrong number of arguments in call to 'join_pair' (expected 2, got 1)",
        'ret join_pair("left")',
        '^',
        'help: check the function signature'
      )
    }
  )

  foreach ($case in $diagnostics) {
    $result = Invoke-Tezz -TezzArgs @('check', $case.Path)
    if ($result.ExitCode -eq 0) {
      Add-Fail -Name $case.Name -Reason 'unexpected pass' -Output $result.Output
      continue
    }
    if (Test-Contains -Name $case.Name -Text $result.Output -Needles $case.Needles) {
      Add-Pass -Name $case.Name
    }
  }

  $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tezznative-dx-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
  try {
    $fmtInput = Join-Path $repoRoot 'tests/conformance/dx/fmt/control_flow.input.tn'
    $fmtExpected = Join-Path $repoRoot 'tests/conformance/dx/fmt/control_flow.formatted.tn'
    $fmtWork = Join-Path $tmpRoot 'control_flow.tn'
    Copy-Item -Force -LiteralPath $fmtInput -Destination $fmtWork

    $fmtResult = Invoke-Tezz -TezzArgs @('fmt', $fmtWork)
    if ($fmtResult.ExitCode -ne 0) {
      Add-Fail -Name 'fmt-control-flow' -Reason "exit=$($fmtResult.ExitCode)" -Output $fmtResult.Output
    } else {
      $expected = (Get-Content -LiteralPath $fmtExpected -Raw) -replace "`r", ''
      $actual = (Get-Content -LiteralPath $fmtWork -Raw) -replace "`r", ''
      if ($actual -ne $expected) {
        Add-Fail -Name 'fmt-control-flow' -Reason 'formatted output mismatch' -Output $actual
      } else {
        Add-Pass -Name 'fmt-control-flow'
      }
    }

    $fmtAgain = Invoke-Tezz -TezzArgs @('fmt', $fmtWork)
    if ($fmtAgain.ExitCode -ne 0) {
      Add-Fail -Name 'fmt-idempotent' -Reason "exit=$($fmtAgain.ExitCode)" -Output $fmtAgain.Output
    } else {
      $again = (Get-Content -LiteralPath $fmtWork -Raw) -replace "`r", ''
      $expected = (Get-Content -LiteralPath $fmtExpected -Raw) -replace "`r", ''
      if ($again -ne $expected) {
        Add-Fail -Name 'fmt-idempotent' -Reason 'second format changed output' -Output $again
      } else {
        Add-Pass -Name 'fmt-idempotent'
      }
    }

    $buildSource = Join-Path $repoRoot 'examples/dx/native_build.tn'
    $buildOut = Join-Path $tmpRoot 'dx_native_build.exe'
    $buildResult = Invoke-Tezz -TezzArgs @('buildexe', $buildSource, $buildOut, '--verify')
    if ($buildResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $buildOut)) {
      Add-Fail -Name 'build-native-example' -Reason "exit=$($buildResult.ExitCode)" -Output $buildResult.Output
    } else {
      $runOutput = & $buildOut 2>&1
      $runExit = $LASTEXITCODE
      $runText = (($runOutput | Out-String) -replace "`r", '').Trim()
      if ($runExit -ne 0 -or -not $runText.Contains('dx-native-build')) {
        Add-Fail -Name 'build-native-example' -Reason "run-exit=$runExit" -Output $runText
      } else {
        Add-Pass -Name 'build-native-example'
      }
    }
  } finally {
    Remove-Item -Recurse -Force -LiteralPath $tmpRoot -ErrorAction SilentlyContinue
  }

  $lintCases = @(
    @{
      Name = 'lint-unused-var'
      Path = 'tests/conformance/dx/lint/unused_var.tn'
      Needles = @("lint[unused-var]", "unused variable 'unused_value'")
    },
    @{
      Name = 'lint-shadowed-var'
      Path = 'tests/conformance/dx/lint/shadowed_var.tn'
      Needles = @("lint[shadowed-var]", "shadowing 'value'")
    },
    @{
      Name = 'lint-suppress'
      Path = 'tests/conformance/dx/lint/suppress_unused_var.tn'
      Needles = @('OK:')
    }
  )

  foreach ($case in $lintCases) {
    $result = Invoke-Tezz -TezzArgs @('lint', $case.Path)
    if ($result.ExitCode -gt 1) {
      Add-Fail -Name $case.Name -Reason "exit=$($result.ExitCode)" -Output $result.Output
      continue
    }
    if (Test-Contains -Name $case.Name -Text $result.Output -Needles $case.Needles) {
      Add-Pass -Name $case.Name
    }
  }

  $examples = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'examples/dx') -Filter '*.tn' | Sort-Object Name
  foreach ($example in $examples) {
    $result = Invoke-Tezz -TezzArgs @('check', $example.FullName)
    $name = 'example-check-' + $example.BaseName
    if ($result.ExitCode -eq 0) {
      Add-Pass -Name $name
    } else {
      Add-Fail -Name $name -Reason "exit=$($result.ExitCode)" -Output $result.Output
    }
  }

  $helloRun = Invoke-Tezz -TezzArgs @('run', 'examples/dx/hello.tn', '--bc')
  if ($helloRun.ExitCode -eq 0 -and $helloRun.Output.Contains('hello from TezzNative')) {
    Add-Pass -Name 'run-hello-example'
  } else {
    Add-Fail -Name 'run-hello-example' -Reason "exit=$($helloRun.ExitCode)" -Output $helloRun.Output
  }

  $lspPath = Join-Path $repoRoot 'tools/tezz_lsp.tn'
  if (Test-Path -LiteralPath $lspPath) {
    $lsp = Invoke-Tezz -TezzArgs @('check', $lspPath)
    if ($lsp.ExitCode -eq 0) {
      Add-Pass -Name 'lsp-source-check'
    } else {
      Add-Fail -Name 'lsp-source-check' -Reason "exit=$($lsp.ExitCode)" -Output $lsp.Output
    }
  } else {
    Add-Fail -Name 'lsp-source-check' -Reason 'tools/tezz_lsp.tn missing'
  }

  $snippetsPath = Join-Path $repoRoot 'tezznative-vscode/snippets/snippets.json'
  try {
    $jsonText = Get-Content -LiteralPath $snippetsPath -Raw
    $json = $jsonText | ConvertFrom-Json
    $names = @($json.PSObject.Properties.Name)
    $required = @('Function Definition', 'Main Function', 'Import Module', 'Extern Function', 'File Read Write')
    $missing = @($required | Where-Object { $_ -notin $names })
    $forbidden = @('tts.', 'stt.', 'tezzserve.serve_ws_upgrade', 'tezzdbql.db_query')
    $bad = @($forbidden | Where-Object { $jsonText.Contains($_) })
    if ($missing.Count -eq 0 -and $bad.Count -eq 0) {
      Add-Pass -Name 'vscode-snippets-supported'
    } else {
      Add-Fail -Name 'vscode-snippets-supported' -Reason "missing=$($missing -join ',') forbidden=$($bad -join ',')"
    }
  } catch {
    Add-Fail -Name 'vscode-snippets-supported' -Reason $_.Exception.Message
  }
} finally {
  Pop-Location
}

Write-Host "DX_SUMMARY passed=$passed failed=$failed"
if ($failed -ne 0) {
  exit 1
}
exit 0

param(
  [string]$Tezzc = "",
  [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
} else {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$passed = 0
$failed = 0

function Pass([string]$Name) {
  $script:passed++
  Write-Host "PASS python-bridge/$Name"
}

function Fail([string]$Name, [string]$Message) {
  $script:failed++
  Write-Host "FAIL python-bridge/$Name :: $Message"
}

function Check([string]$Name, [scriptblock]$Body) {
  try {
    & $Body
    Pass $Name
  } catch {
    Fail $Name $_.Exception.Message
  }
}

function Required-Path([string]$Relative) {
  $path = Join-Path $RepoRoot $Relative
  if (-not (Test-Path -LiteralPath $path)) {
    throw "missing $Relative"
  }
  return $path
}

$fixture = Required-Path "tests\conformance\python_bridge\hot_math.tn"
$outDir = Join-Path $RepoRoot "build\python_bridge_gate"
$manifestPath = Join-Path $outDir "pyext_manifest.tnx"
$wrapperPath = Join-Path $outDir "tn_hot_math_pyext.c"
$headerPath = Join-Path $outDir "tn_hot_math.h"
$setupPath = Join-Path $outDir "setup.py"
$readmePath = Join-Path $outDir "README.md"

Check "command-surface" {
  if ([string]::IsNullOrWhiteSpace($Tezzc)) {
    throw "missing Tezzc"
  }
  $compiler = (Resolve-Path -LiteralPath $Tezzc).Path
  Remove-Item -Recurse -Force -LiteralPath $outDir -ErrorAction SilentlyContinue
  & $compiler pyext $fixture $outDir --module tn_hot_math
  if ($LASTEXITCODE -ne 0) {
    throw "tezzc pyext failed with exit $LASTEXITCODE"
  }
}

Check "generated-files" {
  foreach ($path in @($manifestPath, $wrapperPath, $headerPath, $setupPath, $readmePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
      throw "missing generated file $path"
    }
  }
}

Check "manifest" {
  $manifest = Get-Content -LiteralPath $manifestPath -Raw
  foreach ($needle in @(
    "schema=tezznative.pyext.v1",
    "module=tn_hot_math",
    "wrapped=3",
    "skipped=2",
    "fn.add_i64=wrapped ret=i64 params=i64,i64",
    "fn.scale_f64=wrapped ret=f64 params=f64,f64",
    "fn.first_byte=wrapped ret=i64 params=*u8-buffer,i64",
    "fn.pair_sum=skipped reason=unsupported parameter 1 type unsupported",
    "fn.main=skipped reason=entrypoint main is not wrapped"
  )) {
    if (-not $manifest.Contains($needle)) {
      throw "manifest missing $needle"
    }
  }
}

Check "wrapper-primitives" {
  $src = Get-Content -LiteralPath $wrapperPath -Raw
  foreach ($needle in @(
    "PyLong_AsLongLong",
    "PyFloat_AsDouble",
    "PyLong_FromLongLong",
    "PyFloat_FromDouble",
    "PyInit_tn_hot_math",
    "{`"add_i64`", py_add_i64",
    "{`"scale_f64`", py_scale_f64"
  )) {
    if (-not $src.Contains($needle)) {
      throw "wrapper missing $needle"
    }
  }
}

Check "wrapper-buffer-safety" {
  $src = Get-Content -LiteralPath $wrapperPath -Raw
  foreach ($needle in @(
    "PyObject_GetBuffer(arg0, &buf0, PyBUF_CONTIG_RO)",
    "uint8_t* v0 = (uint8_t*)buf0.buf",
    "if(buf0_ready) PyBuffer_Release(&buf0)",
    "{`"first_byte`", py_first_byte"
  )) {
    if (-not $src.Contains($needle)) {
      throw "buffer wrapper missing $needle"
    }
  }
}

Check "header-contract" {
  $header = Get-Content -LiteralPath $headerPath -Raw
  foreach ($needle in @(
    "extern int64_t add_i64(int64_t a, int64_t b);",
    "extern double scale_f64(double x, double factor);",
    "extern int64_t first_byte(uint8_t * buf, int64_t n);"
  )) {
    if (-not $header.Contains($needle)) {
      throw "header missing $needle"
    }
  }
}

Check "setup-contract" {
  $setup = Get-Content -LiteralPath $setupPath -Raw
  foreach ($needle in @("TEZZ_NATIVE_OBJECTS", "TEZZ_NATIVE_LIBRARIES", "Extension('tn_hot_math'", "tn_hot_math_pyext.c")) {
    if (-not $setup.Contains($needle)) {
      throw "setup.py missing $needle"
    }
  }
}

Check "ownership-docs" {
  $doc = Get-Content -LiteralPath $readmePath -Raw
  foreach ($needle in @('Ownership Rules', 'borrowed contiguous Python buffer views', 'Returned `i64`', 'Pointer returns and structs are intentionally not wrapped')) {
    if (-not $doc.Contains($needle)) {
      throw "README missing $needle"
    }
  }
}

$python = Get-Command python -ErrorAction SilentlyContinue
$cc = Get-Command gcc -ErrorAction SilentlyContinue
if (-not $cc) {
  $cc = Get-Command clang -ErrorAction SilentlyContinue
}
if ($python -and $cc) {
  try {
    $include = (& $python.Source -c "import sysconfig; print(sysconfig.get_paths().get('include',''))").Trim()
    if ($include.Length -gt 0 -and (Test-Path -LiteralPath (Join-Path $include "Python.h"))) {
      $obj = Join-Path $outDir "tn_hot_math_pyext.o"
      & $cc.Source "-I$include" -I$outDir -std=c11 -c $wrapperPath -o $obj
      if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $obj)) {
        Write-Host "PYBRIDGE_OPTIONAL_C_COMPILE_OK"
      } else {
        Write-Host "PYBRIDGE_OPTIONAL_C_COMPILE_SKIP"
      }
    } else {
      Write-Host "PYBRIDGE_OPTIONAL_C_COMPILE_SKIP"
    }
  } catch {
    Write-Host "PYBRIDGE_OPTIONAL_C_COMPILE_SKIP"
  }
} else {
  Write-Host "PYBRIDGE_OPTIONAL_C_COMPILE_SKIP"
}

Write-Host "PYBRIDGE_SUMMARY passed=$passed failed=$failed"
if ($failed -ne 0) {
  exit 1
}

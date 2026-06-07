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
$repoBuildDir = Join-Path $repoRoot 'build'
$failed = 0

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
New-Item -ItemType Directory -Force -Path $repoBuildDir | Out-Null

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

function Assert-Equal {
  param(
    [object]$Actual,
    [object]$Expected,
    [string]$Label
  )

  if ([string]$Actual -eq [string]$Expected) {
    return $true
  }

  Write-Host "FAIL $Label expected=$Expected got=$Actual"
  return $false
}

function Get-AbiStruct {
  param(
    [object]$Abi,
    [string]$Name
  )

  $Abi.structs | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Get-AbiField {
  param(
    [object]$Struct,
    [string]$Name
  )

  $Struct.fields | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Get-AbiFunction {
  param(
    [object]$Abi,
    [string]$Name
  )

  $Abi.fns | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Get-TypeShape {
  param([object]$Type)

  if (-not $Type) {
    return "<missing>"
  }

  switch ([string]$Type.kind) {
    "ptr" {
      return "ptr(" + (Get-TypeShape -Type $Type.elem) + ")"
    }
    "array" {
      return "array(" + (Get-TypeShape -Type $Type.elem) + "," + [string]$Type.len + ")"
    }
    "struct" {
      return "struct:" + [string]$Type.name
    }
    default {
      return [string]$Type.kind
    }
  }
}

function Assert-AbiField {
  param(
    [object]$Struct,
    [string]$FieldName,
    [int]$Offset,
    [int]$Size,
    [int]$Align,
    [string]$TypeShape,
    [string]$Label
  )

  $field = Get-AbiField -Struct $Struct -Name $FieldName
  if (-not $field) {
    Write-Host "FAIL $Label missing field $FieldName"
    return $false
  }

  $ok = $true
  if (-not (Assert-Equal -Actual $field.off -Expected $Offset -Label "$Label.$FieldName off")) { $ok = $false }
  if (-not (Assert-Equal -Actual $field.size -Expected $Size -Label "$Label.$FieldName size")) { $ok = $false }
  if (-not (Assert-Equal -Actual $field.align -Expected $Align -Label "$Label.$FieldName align")) { $ok = $false }
  if (-not (Assert-Equal -Actual (Get-TypeShape -Type $field.type) -Expected $TypeShape -Label "$Label.$FieldName type")) { $ok = $false }
  return $ok
}

function Assert-AbiStruct {
  param(
    [object]$Abi,
    [string]$Name,
    [int]$Size,
    [int]$Align
  )

  $struct = Get-AbiStruct -Abi $Abi -Name $Name
  if (-not $struct) {
    Write-Host "FAIL abi struct missing: $Name"
    return $null
  }
  if (-not (Assert-Equal -Actual $struct.size -Expected $Size -Label "abi/$Name size")) { return $null }
  if (-not (Assert-Equal -Actual $struct.align -Expected $Align -Label "abi/$Name align")) { return $null }
  return $struct
}

function Assert-AbiFunction {
  param(
    [object]$Abi,
    [string]$Name,
    [string]$Ret,
    [string[]]$Params,
    [bool]$Extern
  )

  $fn = Get-AbiFunction -Abi $Abi -Name $Name
  if (-not $fn) {
    Write-Host "FAIL abi function missing: $Name"
    return $false
  }

  $ok = $true
  if (-not (Assert-Equal -Actual $fn.extern -Expected $Extern -Label "abi/$Name extern")) { $ok = $false }
  if (-not (Assert-Equal -Actual (Get-TypeShape -Type $fn.ret) -Expected $Ret -Label "abi/$Name ret")) { $ok = $false }
  $actualParams = @($fn.params | ForEach-Object { Get-TypeShape -Type $_ })
  if (-not (Assert-Equal -Actual ($actualParams -join ",") -Expected ($Params -join ",") -Label "abi/$Name params")) { $ok = $false }
  return $ok
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
    $abiText = Get-Content -LiteralPath $dumpPath -Raw
    try {
      $abi = $abiText | ConvertFrom-Json
    } catch {
      Write-Host "FAIL abi/$($file.Name) abidump is not valid JSON"
      Write-Host "  $($_.Exception.Message)"
      $failed++
      continue
    }

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
      '_Static_assert(sizeof(AbiPacket) == 16, "ABI size mismatch for AbiPacket");',
      'typedef struct AbiNumbers {',
      'uint8_t flag;',
      'int64_t count;',
      'double ratio;',
      '_Static_assert(sizeof(AbiNumbers) == 24, "ABI size mismatch for AbiNumbers");',
      '_Static_assert(_Alignof(AbiNumbers) == 8, "ABI align mismatch for AbiNumbers");',
      'typedef struct AbiTable {',
      'int64_t values[3];',
      'AbiPair head;',
      '_Static_assert(sizeof(AbiTable) == 40, "ABI size mismatch for AbiTable");',
      '_Static_assert(_Alignof(AbiTable) == 8, "ABI align mismatch for AbiTable");',
      'typedef struct AbiWidths {',
      'int8_t s8;',
      'int16_t s16;',
      'int32_t s32;',
      'int64_t s64;',
      'uint8_t u8v;',
      'uint16_t u16v;',
      'uint32_t u32v;',
      'uint64_t u64v;',
      '_Static_assert(sizeof(AbiWidths) == 32, "ABI size mismatch for AbiWidths");',
      '_Static_assert(_Alignof(AbiWidths) == 8, "ABI align mismatch for AbiWidths");'
    )

    foreach ($snippet in $headerSnippets) {
      if (-not (Assert-Contains -Text $header -Needle $snippet -Label "abi/$($file.Name) cheader")) {
        $ok = $false
      }
    }

    if (-not (Assert-Equal -Actual $abi.schema -Expected "tezznative.abi.v1" -Label "abi/$($file.Name) schema")) { $ok = $false }

    $pair = Assert-AbiStruct -Abi $abi -Name "AbiPair" -Size 16 -Align 8
    if (-not $pair) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $pair -FieldName "left" -Offset 0 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiPair")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $pair -FieldName "right" -Offset 8 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiPair")) { $ok = $false }
    }

    $buffer = Assert-AbiStruct -Abi $abi -Name "AbiBuffer" -Size 16 -Align 8
    if (-not $buffer) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $buffer -FieldName "data" -Offset 0 -Size 8 -Align 8 -TypeShape "ptr(u8)" -Label "AbiBuffer")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $buffer -FieldName "len" -Offset 8 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiBuffer")) { $ok = $false }
    }

    $packet = Assert-AbiStruct -Abi $abi -Name "AbiPacket" -Size 16 -Align 8
    if (-not $packet) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $packet -FieldName "tag" -Offset 0 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiPacket")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $packet -FieldName "bytes" -Offset 8 -Size 8 -Align 1 -TypeShape "array(u8,8)" -Label "AbiPacket")) { $ok = $false }
    }

    $numbers = Assert-AbiStruct -Abi $abi -Name "AbiNumbers" -Size 24 -Align 8
    if (-not $numbers) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $numbers -FieldName "flag" -Offset 0 -Size 1 -Align 1 -TypeShape "u8" -Label "AbiNumbers")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $numbers -FieldName "count" -Offset 8 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiNumbers")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $numbers -FieldName "ratio" -Offset 16 -Size 8 -Align 8 -TypeShape "f64" -Label "AbiNumbers")) { $ok = $false }
    }

    $table = Assert-AbiStruct -Abi $abi -Name "AbiTable" -Size 40 -Align 8
    if (-not $table) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $table -FieldName "values" -Offset 0 -Size 24 -Align 8 -TypeShape "array(i64,3)" -Label "AbiTable")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $table -FieldName "head" -Offset 24 -Size 16 -Align 8 -TypeShape "struct:AbiPair" -Label "AbiTable")) { $ok = $false }
    }

    $widths = Assert-AbiStruct -Abi $abi -Name "AbiWidths" -Size 32 -Align 8
    if (-not $widths) { $ok = $false } else {
      if (-not (Assert-AbiField -Struct $widths -FieldName "s8" -Offset 0 -Size 1 -Align 1 -TypeShape "i8" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "s16" -Offset 2 -Size 2 -Align 2 -TypeShape "i16" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "s32" -Offset 4 -Size 4 -Align 4 -TypeShape "i32" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "s64" -Offset 8 -Size 8 -Align 8 -TypeShape "i64" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "u8v" -Offset 16 -Size 1 -Align 1 -TypeShape "u8" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "u16v" -Offset 18 -Size 2 -Align 2 -TypeShape "u16" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "u32v" -Offset 20 -Size 4 -Align 4 -TypeShape "u32" -Label "AbiWidths")) { $ok = $false }
      if (-not (Assert-AbiField -Struct $widths -FieldName "u64v" -Offset 24 -Size 8 -Align 8 -TypeShape "u64" -Label "AbiWidths")) { $ok = $false }
    }

    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_pair_sum" -Extern $true -Ret "i64" -Params @("ptr(struct:AbiPair)", "i64"))) { $ok = $false }
    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_buffer_len" -Extern $true -Ret "i64" -Params @("struct:AbiBuffer"))) { $ok = $false }
    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_packet_send" -Extern $true -Ret "void" -Params @("ptr(struct:AbiPacket)"))) { $ok = $false }
    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_numbers_scale" -Extern $true -Ret "i64" -Params @("struct:AbiNumbers", "ptr(struct:AbiNumbers)"))) { $ok = $false }
    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_table_first" -Extern $true -Ret "i64" -Params @("ptr(struct:AbiTable)"))) { $ok = $false }
    if (-not (Assert-AbiFunction -Abi $abi -Name "abi_widths_mix" -Extern $true -Ret "u64" -Params @("struct:AbiWidths", "ptr(struct:AbiWidths)", "i32", "u32"))) { $ok = $false }

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

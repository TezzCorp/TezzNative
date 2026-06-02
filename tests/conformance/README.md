# TezzNative Conformance Tests

This directory is the first public conformance corpus for the stable language
core. The tests are intentionally small and focused so compiler regressions are
easy to diagnose.

## Layout

- `valid/` contains stable-core programs that must pass `tezzc check`.
- `parser/valid` and `parser/invalid` contain parser-focused acceptance and
  rejection fixtures.
- `typecheck/valid` and `typecheck/invalid` contain semantic/type-system
  acceptance and rejection fixtures.
- `invalid/` contains legacy stable-core programs that must fail `tezzc check`.
- `diagnostics/` contains expected diagnostic snippets for invalid programs,
  including parser and typecheck subdirectories.
- `stdlib/` contains stable standard-library import smoke programs.
- `native/` contains native-backend smoke programs.
- `abi/` contains starter C ABI layout and signature fixtures.

The stable-core runner currently gates 26 cases across flat stable-core,
parser, typecheck, diagnostics, and stdlib-import suites. It covers
arithmetic/control flow, comments/literals, nested blocks, structs, fixed
arrays, indexing, `sizeof`/`alignof`, unsafe pointer operations, function
calls/returns, common type errors, unknown names/fields, wrong call arity,
parser errors, and unsafe diagnostics.

## Runner

From a development checkout:

```powershell
.\tests\conformance\run.ps1
```

The runner uses `.\TezzNative-language\bin\tezzc.exe` when it exists, then
falls back to `tezzc` on `PATH`. A custom compiler can be passed explicitly:

```powershell
.\tests\conformance\run.ps1 -Tezzc C:\tools\tezzc.exe
```

On Linux or WSL:

```bash
bash tests/conformance/run.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The runner checks diagnostic snippets when a matching `.diag.txt` file exists.
Parser diagnostics live under `diagnostics/parser`; type-checker diagnostics
live under `diagnostics/typecheck`.

Native smoke tests cover executable hello output, loops/math, deterministic
`math` helpers, strings and string transforms, struct-array field access, raw,
wrapped, line-oriented, and chunked stream file IO, directory lifecycle,
portable path helpers, vectors, arenas, and time clock/sleep/UTC-date helpers:

```powershell
.\tests\conformance\run-native-smoke.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-native-smoke.sh ./TezzNative-language/bin/tezzc-linux-x64
```

Native reliability tests build focused fixtures twice, compare executable
SHA-256 hashes, run host-safe outputs, and prove unknown native targets fail
closed without producing an artifact:

```powershell
.\tests\conformance\run-native-reliability.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-native-reliability.sh ./TezzNative-language/bin/tezzc-linux-x64
```

ABI starter tests:

```powershell
.\tests\conformance\run-abi.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-abi.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The ABI runner checks generated C header layout assertions, strict JSON
`abidump`, and `abiverify` for pointer fields, fixed arrays, nested structs,
scalar mixes, field offsets, by-value struct parameters, and extern signatures.
Windows and Linux CI run the same full verification lane.

# TezzNative Conformance Tests

This directory is the first public conformance corpus for the stable language
core. The tests are intentionally small and focused so compiler regressions are
easy to diagnose.

## Layout

- `valid/` contains programs that must pass `tezzc check`.
- `invalid/` contains programs that must fail `tezzc check`.
- `diagnostics/` contains expected diagnostic snippets for invalid programs.
- `stdlib/` contains stable standard-library import smoke programs.
- `native/` contains native-backend smoke programs.
- `abi/` contains starter C ABI layout and signature fixtures.

The stable-core corpus currently covers arithmetic/control flow, structs,
fixed arrays, indexing, `sizeof`/`alignof`, unsafe pointer operations, common
type errors, unknown names/fields, wrong call arity, and unsafe diagnostics.

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

The runner checks diagnostic snippets when `diagnostics/<test-name>.diag.txt`
exists. The next step is to expand these snippets into full normalized
snapshots.

Native smoke tests cover executable hello output, loops/math, deterministic
`math` helpers, strings and string transforms, struct-array field access, raw,
wrapped, line-oriented, and chunked stream file IO, portable path helpers,
vectors, arenas, and time clock/sleep/UTC-date helpers:

```powershell
.\tests\conformance\run-native-smoke.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-native-smoke.sh ./TezzNative-language/bin/tezzc-linux-x64
```

ABI starter tests:

```powershell
.\tests\conformance\run-abi.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-abi.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The ABI runner checks generated C header layout assertions, `abidump`, and
`abiverify` for pointer fields, fixed arrays, nested structs, scalar mixes, and
extern signatures. CI may pass `-SkipVerify` until hosted-runner `abiverify`
behavior is hardened. The runner uses targeted dump snippets until the full
`abidump` output is strict JSON.

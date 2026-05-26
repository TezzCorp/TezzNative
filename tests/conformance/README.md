# TezzNative Conformance Tests

This directory is the first public conformance corpus for the stable language
core. The tests are intentionally small and focused so compiler regressions are
easy to diagnose.

## Layout

- `valid/` contains programs that must pass `tezzc check`.
- `invalid/` contains programs that must fail `tezzc check`.
- `diagnostics/` contains expected diagnostic snippets for invalid programs.
- `native/` contains native-backend smoke programs.
- `abi/` contains starter C ABI layout and signature fixtures.

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

The runner checks diagnostic snippets when `diagnostics/<test-name>.diag.txt`
exists. The next step is to expand these snippets into full normalized
snapshots.

Native smoke tests:

```powershell
.\tests\conformance\run-native-smoke.ps1
```

ABI starter tests:

```powershell
.\tests\conformance\run-abi.ps1
```

The ABI runner checks generated C header layout assertions, `abidump`, and
`abiverify`. It uses targeted dump snippets until the full `abidump` output is
strict JSON.

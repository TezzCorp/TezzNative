# TezzNative Conformance Tests

This directory is the first public conformance corpus for the stable language
core. The tests are intentionally small and focused so compiler regressions are
easy to diagnose.

## Layout

- `valid/` contains programs that must pass `tezzc check`.
- `invalid/` contains programs that must fail `tezzc check`.

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

The next step is to add CI jobs and diagnostic snapshots.

# TezzNative Benchmarks

This directory is the public benchmark harness skeleton. It is intentionally
small and conservative: the goal is repeatable measurement, not marketing
numbers.

## Rules

- Record hardware, OS, compiler path, command, exit code, timing, and binary
  size where available.
- Keep TezzNative bytecode and native measurements separate.
- Keep Python and C comparison fixtures source-visible.
- Do not publish a performance claim without the generated CSV and environment
  metadata.
- Treat missing optional tools such as Python or a C compiler as skipped, not as
  a benchmark result.

## Run

Check only:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -CheckOnly
```

Run TezzNative benchmarks:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1
```

Include Python and C comparison fixtures when available:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -IncludeExternal
```

On Linux or WSL, validate the TezzNative benchmark fixture with:

```bash
bash benchmarks/run.sh ./TezzNative-language/bin/tezzc-linux-x64 --check-only
```

Results are written to `benchmarks/results/latest.csv` by default.

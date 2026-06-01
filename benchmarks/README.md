# TezzNative Benchmarks

This directory is the public benchmark harness. It is intentionally
conservative: the goal is repeatable measurement, not marketing numbers.

## Rules

- Record hardware/host details, OS, compiler path, command, exit code, timing,
  peak memory where available, output hash, and binary size where available.
- Keep TezzNative bytecode and native measurements separate.
- Keep Python, C, Node.js, Go, and Rust comparison fixtures source-visible.
- Do not publish a performance claim without the generated CSV and environment
  metadata.
- Treat missing optional tools as skipped, not as a benchmark result.

## Run

Check only:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -CheckOnly
```

Run TezzNative benchmarks:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1
```

Include optional Python, C, Node.js, Go, and Rust comparison fixtures when
available:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -IncludeExternal
```

On Linux or WSL, validate the TezzNative benchmark fixture with:

```bash
bash benchmarks/run.sh ./TezzNative-language/bin/tezzc-linux-x64 --check-only
```

Results are written to `benchmarks/results/latest.csv` by default.
See `docs/BENCHMARKS.md` for the workload matrix, result schema, and publishing
rules.

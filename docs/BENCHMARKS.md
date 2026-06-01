# TezzNative Benchmarks

TezzNative benchmarks are evidence, not advertising. A performance claim should
only be published with the source fixture, exact command, generated CSV, and
run metadata.

## Current Public Workloads

| Workload | Category | What It Measures | TezzNative Modes |
| --- | --- | --- | --- |
| `startup` | Startup time | Process launch plus minimal program startup | check, bytecode, native |
| `sum_loop` | Numeric loop | Integer loop lowering and arithmetic throughput | check, bytecode, native |
| `string_scan` | String processing | Byte scanning, nested loops, and integer accumulation | check, bytecode, native |
| `file_io` | File read/write | Binary file write, size check, readback, byte accumulation, cleanup | check, bytecode, native |

The same workload names are mirrored where practical under `benchmarks/python`,
`benchmarks/c`, `benchmarks/node`, `benchmarks/go`, and `benchmarks/rust`.
Those language toolchains are optional: missing tools are reported as skipped,
not as results.

## Not Claimed Yet

These categories stay out of performance claims until source-visible fixtures
and platform gates exist:

| Category | Status |
| --- | --- |
| JSON parsing | Waiting for a stable JSON module or first-party package fixture. |
| HTTP server throughput | Waiting for a dedicated local load-driver and stable server fixture. |
| Matrix math | Waiting for a real supported numeric backend target and correctness gate. |
| GPU/NPU/LLM | Experimental only; fallback results must never be labeled as hardware acceleration. |

## Result Files

PowerShell writes:

- `benchmarks/results/latest.csv`
- `benchmarks/results/latest.metadata.json`

The POSIX runner writes:

- `benchmarks/results/latest-linux.csv`
- `benchmarks/results/latest-linux.metadata.json`

CSV rows use schema `tezznative.benchmark-result.v1` and include:

- OS, architecture, processor count.
- benchmark name and category.
- language, mode, phase, and iteration.
- elapsed milliseconds.
- peak working set bytes where the host exposes it.
- binary size for compiled artifacts.
- exit code, timeout status, command, and output hash.

Metadata files use schema `tezznative.benchmark-run.v1` and record the compiler
path, iteration count, run mode, timeout, and host details.

## Commands

Check TezzNative benchmark fixtures only:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -CheckOnly
```

Run TezzNative bytecode/native measurements:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1
```

Include optional Python, C, Node.js, Go, and Rust comparisons:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1 -IncludeExternal
```

On Linux or WSL:

```bash
bash benchmarks/run.sh ./TezzNative-language/bin/tezzc-linux-x64 --iterations 3 --include-external
```

For CI fixture validation:

```bash
bash benchmarks/run.sh ./TezzNative-language/bin/tezzc-linux-x64 --check-only
```

## Publishing Rule

Before publishing benchmark numbers:

1. Run at least three iterations.
2. Include the generated CSV and metadata.
3. State OS, CPU, compiler path, and toolchain versions when available.
4. Keep bytecode and native TezzNative results separate.
5. Include losing or incomplete results instead of filtering them out.
6. Label skipped optional tools as skipped, not slower or faster.

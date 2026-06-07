# TezzNative Conformance

The conformance corpus is the first compatibility contract for the stable
language core. It is intentionally small, organized, and deterministic so
compiler regressions can be diagnosed quickly.

## Public Suites

| Suite | Path | Purpose |
| --- | --- | --- |
| Stable core | `tests/conformance/valid` | Arithmetic, control flow, structs, arrays, indexing, fixed-width integers, `sizeof`, `alignof`, and unsafe pointer basics. |
| Parser valid | `tests/conformance/parser/valid` | Comments, literals, nested blocks, struct syntax, and fixed-array syntax. |
| Parser invalid | `tests/conformance/parser/invalid` | Bad indentation, missing block markers, and unterminated strings. |
| Typecheck valid | `tests/conformance/typecheck/valid` | Function calls/returns, pointer-array roundtrip, and struct value flow. |
| Typecheck invalid | `tests/conformance/typecheck/invalid` | Array index type errors, return value mismatch, and struct field assignment mismatch. |
| Diagnostics | `tests/conformance/invalid` plus `tests/conformance/diagnostics` | Named unknown symbols, wrong arity, unsafe address-of, field errors, and stable diagnostic snippets. |
| Stdlib import | `tests/conformance/stdlib` | Stable-candidate module import smoke. |
| Developer experience | `tests/conformance/run-dx.*` plus `tests/conformance/dx` | Actionable diagnostics, formatter idempotence, lint rule IDs, examples, LSP source health, and VS Code snippet drift checks. |
| Package trust | `tests/conformance/run-package-trust.*` | Public `tezz` launchers/tool source, SemVer package metadata, lock/registry parity, package checksums, generated package docs, and first-party package target docs. |
| Python bridge | `tests/conformance/run-python-bridge.*` plus `tests/conformance/python_bridge` | `tezzc pyext` command generation, CPython wrapper contents, primitive/buffer mapping, ownership docs, and wrapped/skipped manifests. |
| C ABI | `tests/conformance/run-abi.*` plus `tests/conformance/abi` | C header emission, structured ABI dump/verify, struct layout, fixed-width integer mappings, and extern signatures. |
| Native smoke | `tests/conformance/run-native-smoke.*` | Native build, verify, run, and stdout comparison on Windows/Linux x64. |
| Native reliability | `tests/conformance/run-native-reliability.*` | Byte-reproducible native output and fail-closed unsupported-target behavior. |

The current stable-core runner gates 27 checks across Windows and Linux:

- 14 valid programs must pass `tezzc check`.
- 13 invalid programs must fail with deterministic diagnostic snippets.

## Commands

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run.ps1
```

Linux or WSL:

```bash
bash tests/conformance/run.sh ./TezzNative-language/bin/tezzc-linux-x64
```

Both runners print suite-qualified result names and end with:

```text
CONFORMANCE_SUMMARY passed=27 failed=0
```

Run the developer experience gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-dx.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run-dx.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The DX runner ends with:

```text
DX_SUMMARY passed=19 failed=0
```

Run the package trust gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-package-trust.ps1 -Tezzc .\TezzNative-language\build\tezzc.exe
```

On Linux or WSL:

```bash
bash tests/conformance/run-package-trust.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The package trust runner ends with:

```text
PACKAGE_TRUST_SUMMARY passed=12 failed=0
```

Run the Python bridge gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-python-bridge.ps1 -Tezzc .\TezzNative-language\build\tezzc.exe
```

On Linux or WSL:

```bash
bash tests/conformance/run-python-bridge.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The Python bridge runner ends with:

```text
PYBRIDGE_SUMMARY passed=8 failed=0
```

## Rules For New Tests

- A valid fixture must be small and deterministic.
- An invalid fixture must have one primary failure reason.
- If a diagnostic snippet exists, it must be stable across Windows/Linux paths.
- Runtime, native backend, ABI, benchmark, and stdlib expansion tests should
  stay in their dedicated suites instead of weakening the stable-core signal.
- DX fixtures should prove first-user workflows and editor/tooling behavior
  without depending on public network access or machine-specific paths.
- Package-trust fixtures should validate metadata, deterministic ordering, and
  checksum/provenance behavior without requiring public network access.

## Native Backend Gates

Native smoke cases live under `tests/conformance/native`. They build native
executables with `buildexe`, verify the output format where supported, run the
executable, and compare stdout when a `.stdout.txt` file exists.

Current native smoke coverage includes hello output, loop/math lowering, string
helpers and transforms, file IO, directory lifecycle/listing/glob, portable
paths, fixed-width integer truncation and signed/unsigned load extension,
vectors, arenas, time helpers, process output, many-argument calls, local TCP
loopback, socket options, IPv4 literal bind hosts, localhost wrappers, local
HTTP route helpers, keep-alive HTTP response reads, and stable-candidate stdlib
edge fixtures for math, strings, vectors, and arenas.

Native reliability cases build focused host-safe fixtures twice and compare the
resulting executable SHA-256 hashes. They also assert that an unknown
`buildexe --target` exits non-zero and does not emit an artifact. This protects
the Milestone 2 release gate for deterministic output and fail-closed target
handling.

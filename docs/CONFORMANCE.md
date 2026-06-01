# TezzNative Conformance

The conformance corpus is the first compatibility contract for the stable
language core. It is intentionally small, organized, and deterministic so
compiler regressions can be diagnosed quickly.

## Public Suites

| Suite | Path | Purpose |
| --- | --- | --- |
| Stable core | `tests/conformance/valid` | Arithmetic, control flow, structs, arrays, indexing, `sizeof`, `alignof`, and unsafe pointer basics. |
| Parser valid | `tests/conformance/parser/valid` | Comments, literals, nested blocks, struct syntax, and fixed-array syntax. |
| Parser invalid | `tests/conformance/parser/invalid` | Bad indentation, missing block markers, and unterminated strings. |
| Typecheck valid | `tests/conformance/typecheck/valid` | Function calls/returns, pointer-array roundtrip, and struct value flow. |
| Typecheck invalid | `tests/conformance/typecheck/invalid` | Array index type errors, return value mismatch, and struct field assignment mismatch. |
| Diagnostics | `tests/conformance/invalid` plus `tests/conformance/diagnostics` | Named unknown symbols, wrong arity, unsafe address-of, field errors, and stable diagnostic snippets. |
| Stdlib import | `tests/conformance/stdlib` | Stable-candidate module import smoke. |

The current stable-core runner gates 26 checks across Windows and Linux:

- 13 valid programs must pass `tezzc check`.
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
CONFORMANCE_SUMMARY passed=26 failed=0
```

## Rules For New Tests

- A valid fixture must be small and deterministic.
- An invalid fixture must have one primary failure reason.
- If a diagnostic snippet exists, it must be stable across Windows/Linux paths.
- Runtime, native backend, ABI, benchmark, and stdlib expansion tests should
  stay in their dedicated suites instead of weakening the stable-core signal.

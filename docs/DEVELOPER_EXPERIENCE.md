# TezzNative Developer Experience

Milestone 4 makes the first-user path measurable. A new user should be able to
check, run, format, lint, build, inspect diagnostics, and open examples without
private knowledge of the repository.

## Public DX Gate

Run the gate on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-dx.ps1
```

Run the gate on Linux or WSL:

```bash
bash tests/conformance/run-dx.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The gate covers:

- actionable diagnostics for unknown names and wrong arity.
- formatter idempotence for control flow.
- lint rule IDs for unused variables and shadowed variables.
- lint suppression behavior through a clean suppress fixture.
- checkable first examples under `examples/dx`.
- `tezzc run` for hello world.
- `tezzc buildexe --verify` plus execution for a native example.
- TezzNative LSP source type-checking.
- VS Code snippets constrained to supported syntax and stable examples.

Expected summary:

```text
DX_SUMMARY passed=19 failed=0
```

## Diagnostics Contract

Compiler errors should include:

- file, line, and column.
- the primary error message.
- a source snippet and caret.
- expected/actual information when the compiler has it.
- one short `help:` line when an actionable hint is known.

Snapshot tests should match stable substrings instead of absolute local paths.

## Formatter Contract

`tezzc fmt` must be idempotent. Running it twice on the same file should produce
the same bytes. Formatter fixtures live under `tests/conformance/dx/fmt`.

## Lint Contract

`tezzc lint` warnings should include rule IDs such as `lint[unused-var]` and
`lint[shadowed-var]`. Public examples and editor snippets should avoid relying
on unstable or experimental modules unless the example is explicitly marked as
beta or experimental.

## Examples

The curated first examples live under `examples/dx`:

| Example | Purpose | Gate |
| --- | --- | --- |
| `hello.tn` | Basic run flow | check + run |
| `cli_flags.tn` | CLI-style flag handling | check |
| `file_read_write.tn` | Stable-candidate file wrapper flow | check |
| `http_request_parse.tn` | Deterministic HTTP response parsing | check |
| `http_server_route_once.tn` | Route matching before server execution | check |
| `c_extern_call.tn` | C ABI extern call shape | check |
| `native_build.tn` | Native executable build and run | check + build + run |
| `tezzdb_small.tn` | Beta embedded database starter | check |

## Editor Surface

The VS Code snippet file is part of the DX gate. Snippets should match syntax
that `tezzc check` accepts today, and aspirational snippets for experimental
modules should stay out of the default beginner path until they have public
examples and tests.

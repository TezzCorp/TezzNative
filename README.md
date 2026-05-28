# TezzNative

TezzNative is a Python-readable, C-adjacent native programming language. It is
designed for developers who want simple syntax, static typing, native binaries,
manual low-level control when needed, and a bundled standard library.

This repository is the public TezzNative distribution surface. It contains:

- The TezzNative standard library in `lib/`
- The package metadata in `tezz.mod`, `tezz.lock`, and `version.json`
- The official VS Code language extension in `tezznative-vscode/`
- Public project documentation

Current language metadata: **TezzNative 1.1.0**, release channel, API `v1`.

## Project Goal

TezzNative is not trying to clone Python or C. The strongest target is:

> Python-like readability with C-like native deployment.

The best early use cases are CLI tools, automation scripts, native utilities,
small services, embedded runtime experiments, and C interop code where Python is
too slow or C is too noisy.

## Status

TezzNative is active and ambitious, but the stable core is intentionally smaller
than the full repository surface.

| Area | Status | Notes |
| --- | --- | --- |
| Core syntax | Stable (gated) | Functions, variables, control flow, structs, arrays, imports, `sizeof`/`alignof`, and unsafe pointer blocks |
| Static type checking | Stable/Beta (gated core) | Type mismatch, unknown name/field, arity, and unsafe diagnostics are snippet checked; richer help is still improving |
| Native executable flow | Beta (gated x64) | Windows/Linux SDKs build and run hello, loops/math module, strings/transforms, structs, raw/wrapped/line/stream file IO, directory lifecycle, direct `dir_list`, `glob_list`, portable paths, vectors, arenas, and time clock/sleep/UTC-date helpers |
| Bytecode run flow | Stable/Beta | Useful for development and compatibility |
| C ABI / extern calls | Beta (gated starter) | Header/ABI dump checks cover pointers, arrays, nested structs, scalar mixes, and extern signatures |
| Stable stdlib candidates | Stable/Beta (smoke gated) | Core imports plus native math, string, raw/wrapped/line/stream file IO, directory lifecycle, direct `dir_list`, public `glob_list`, portable path, vector, arena, and `time` clock/sleep/UTC-date smoke; VM/runtime gates cover deterministic recursive listing and raw glob filters. Direct-native recursive listing and process-output calls fail closed until OS-backed parity lands |
| Networking/TLS/GUI/DB | Beta | Useful, but needs platform matrix testing |
| GPU/NPU/LLM/kernel modules | Experimental | API surface exists; backend support depends on runtime build |

See `docs/STABILITY.md` for the full stability map.
See `docs/PLATFORM_SUPPORT.md` for target support and
`docs/STDLIB_INVENTORY.md` for module maturity.

## Quick Example

```tn
import "std"

fn fib(n:int) -> int:
  if n <= 1:
    ret n
  ret fib(n - 1) + fib(n - 2)

fn main() -> int:
  say "fib(10) = ", fib(10)
  ret 0
```

Typical commands:

```bash
tezzc check hello.tn
tezzc run hello.tn
tezzc buildexe hello.tn hello.exe
tezzc buildexe hello.tn ./hello --target linux
```

## Language Snapshot

TezzNative currently supports:

- Indentation-based blocks
- `fn`, `let`, `struct`, `enum`, `typedef`, `extern`, and `static`
- `if`, `else`, `while`, C-style `for`, `switch`, `break`, `continue`, `ret`
- Primitive types such as `int`, `float`, `char`, `str`, `void`
- Pointers, arrays, casts, indexing, field access, `sizeof`, and `alignof`
- `unsafe` blocks for pointer and low-level memory operations
- C ABI-oriented attributes and extern declarations
- A bundled module system and standard library

## Standard Library

The public `lib/` directory includes modules for:

- Core utilities: `std`, `io`, `str`, `math`, `vec`, `arena`, `time`
- Systems work: `sys`, `mmap`, `os`, `kernel`, `arduino`, `raspi`
- Networking: `net`, `tls`, `tezzserve`, `tezzapi`
- UI/application work: `gui`, `gui_win`, `tzgui`, `tzui`, `tnui`, `tezzui`
- Data and AI experiments: `tezzdb`, `tensor`, `nn`, `llm`, `tokenizer`, `tts`, `stt`
- Acceleration surfaces: `simd`, `intrin`, `gpu`, `npu`

Not every module has the same maturity level. Stable applications should start
with the core modules and opt into experimental modules deliberately.

## Tooling

The compiler and wrapper tooling are designed around a simple workflow:

- `check`: parse and type-check a program
- `run`: execute through the supported runtime path
- `buildexe`: build a native executable where supported
- `fmt`: format source
- `lint`: run static lint rules
- `cheader`, `abidump`, `abiverify`: inspect and verify C ABI surfaces

The VS Code extension provides syntax highlighting, snippets, and editor
integration for TezzNative files.

The first public stable-core conformance corpus is available in
`tests/conformance/`. Run it with:

```powershell
.\tests\conformance\run.ps1
```

On Linux or WSL:

```bash
bash tests/conformance/run.sh ./TezzNative-language/bin/tezzc-linux-x64
```

Invalid conformance tests may also have diagnostic snippets under
`tests/conformance/diagnostics/`. GitHub Actions runs the same stable-core
corpus, including stable stdlib import smoke tests, against the published
Windows and Linux SDK packages.

The native backend smoke lane builds and runs small executable programs for
hello output, loops/math, math module helpers, strings and transforms, structs,
raw/wrapped/line/stream file IO, directory lifecycle, direct directory listing,
public glob filters, portable path helpers, vectors, arenas, and time
clock/sleep/UTC-date helpers:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-native-smoke.ps1
```

CI runs the same lane as a hosted Windows and Linux execution gate. Local runs
can use the default execute mode, `-CheckIrOnly`, or `-BuildOnly` for deeper
backend verification.

On Linux or WSL:

```bash
bash tests/conformance/run-native-smoke.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The first ABI starter lane checks C header layout assertions plus ABI dump and
verify behavior:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-abi.ps1
```

CI uses `-SkipVerify` for this lane until hosted-runner `abiverify` behavior is
hardened; local full verification is available with the default command above.
Linux CI runs the POSIX ABI runner with full local `abiverify` against the
published Linux SDK.

The public benchmark skeleton records environment metadata, bytecode timing,
native build timing, native run timing, exit codes, and binary size:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run.ps1
```

Use `-IncludeExternal` to run the Python and C comparison fixtures when those
toolchains are available.

On Linux or WSL:

```bash
bash benchmarks/run.sh ./TezzNative-language/bin/tezzc-linux-x64 --check-only
```

## Optimization Roadmap

The current priority is trust over feature count:

1. Stabilize and document the core language subset.
2. Split stable, beta, and experimental standard library surfaces.
3. Expand compiler, ABI, and runtime conformance tests.
4. Harden x86_64 native builds before widening target claims.
5. Improve diagnostics, package metadata, examples, and benchmarks.

See `docs/OPTIMIZATION_PLAN.md` for the working roadmap.

## Repository Notes

The public repository intentionally tracks a clean distribution subset. Full
compiler sources, generated binaries, installers, local deployment scripts, and
site deployment data may exist in local development directories but are not part
of this public Git surface unless explicitly added.

## License

See `LICENSE.txt`.

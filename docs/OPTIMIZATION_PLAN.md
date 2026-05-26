# TezzNative Optimization Plan

This is the execution roadmap for turning TezzNative from an ambitious language
surface into a trusted native programming platform.

The strategy is not to add more features first. The strategy is to make the
core impossible to ignore: predictable compiler behavior, stable language
contracts, clear module maturity, native performance proof, and excellent
developer experience.

## North Star

TezzNative should become the language for:

> Python-readable native programming with C-level control and single-binary
> deployment.

The strongest adoption path is:

1. Win CLI tools and automation scripts.
2. Win native utilities and small services.
3. Win C interop and Python acceleration use cases.
4. Expand into larger systems, GUI, database, and runtime work after trust is
   earned.

## Product Position

TezzNative should not claim to replace Python or C everywhere. The sharper
message is:

> Use TezzNative where Python feels slow and C feels painful.

This gives the language a believable wedge:

- Python-like readability.
- Static checks before runtime.
- Native executable output.
- Manual memory and C ABI when needed.
- A bundled standard library for practical programs.

## Current Priority

Trust beats feature count.

The repository already contains a wide standard library and experimental
runtime surfaces. The next optimization pass must make the language reliable,
measurable, and easy to adopt.

## Stability Policy

All public surfaces should be labeled:

| Label | Meaning | Change Policy |
| --- | --- | --- |
| Stable | Normal application use | Breaking changes require migration notes |
| Beta | Useful but still hardening | Breaking changes allowed with release notes |
| Experimental | Design and backend validation | APIs may change or be removed |
| Internal | Compiler/runtime implementation | No compatibility promise |

Stable and beta documentation must explain platform support, fallback behavior,
and examples. Experimental modules must be clearly marked so ambition does not
damage trust.

## Milestone 0: Public Trust Baseline

Status: started.

Goal: make the public project story accurate, restrained, and useful.

Delivered:

- Replaced broad marketing claims with an accurate capability map.
- Added public stability documentation.
- Added this optimization roadmap.
- Marked GPU and NPU modules as experimental surfaces.
- Corrected public metadata and duplicated manifest entries.
- Added the initial platform support matrix.
- Added the initial standard library maturity inventory.

Exit gate:

- GitHub README describes the real 1.1.0 state.
- Website has public stability and roadmap pages.
- Stable, beta, and experimental labels are visible to new users.

## Milestone 1: Conformance And Correctness Harness

Status: started.

Goal: make compiler correctness measurable before deep backend work.

Build these test groups:

| Suite | Coverage |
| --- | --- |
| Lexer/parser | Valid syntax, invalid syntax, indentation, literals, comments |
| Type checker | Calls, returns, casts, arrays, structs, pointers, externs |
| Unsafe rules | Deref, address-of, pointer arithmetic, borrowed values, free checks |
| Diagnostics | Snapshot tests for common user errors |
| IR verifier | Labels, control flow, loads, stores, calls, conversions, returns |
| Native smoke | Hello world, math, strings, structs, file IO, loops |
| ABI | Struct layout, function signatures, header generation, abidump/abiverify |
| Stdlib smoke | Core module imports and small examples |

Acceptance gates:

- `tezzc check` never crashes on the test corpus.
- Invalid programs fail with deterministic diagnostics.
- Valid stable-core programs pass on every supported development platform.
- Native smoke tests pass for x86_64 Windows and x86_64 Linux before new native
  backend claims are added.

Immediate tasks:

1. Create `tests/conformance/parser`.
2. Create `tests/conformance/typecheck`.
3. Create `tests/conformance/diagnostics`.
4. Add a small test runner command that returns non-zero on failure. Done:
   `tests/conformance/run.ps1`.
5. Add CI jobs for stable-core checks.

Started:

- Added the public `tests/conformance` corpus with stable-core valid and invalid
  cases for arithmetic, control flow, structs, type mismatches, and unknown
  names.
- Added diagnostic snippet checks for the first invalid conformance cases.

## Milestone 2: Native Backend Reliability

Status: started.

Goal: make native builds dependable for a narrow target set before expanding.

Primary targets:

- x86_64 Windows
- x86_64 Linux

Secondary targets after the primary gates pass:

- x86_64 macOS
- aarch64 Linux
- aarch64 macOS

Backend work:

- Track supported IR operations by target.
- Add a native backend feature matrix.
- Add register allocation stress tests.
- Add stack frame and calling convention tests.
- Add constant folding and dead code elimination tests.
- Add loop lowering tests.
- Add string/global data emission tests.
- Add import table and syscall/backend-specific tests.

Optimization order:

1. Correctness.
2. Deterministic output.
3. Debuggability.
4. Simple IR optimizations.
5. Register allocation quality.
6. Platform expansion.

Release gate:

- Native executable output must be reproducible for stable examples.
- Backend failures must produce clear errors instead of silent bad output.
- Unsupported targets must fail explicitly.

Started:

- Added the first native smoke runner:
  `tests/conformance/run-native-smoke.ps1`.
- Added native executable smoke cases for hello output, loop/math lowering, and
  struct array field access.
- Added native-focused deterministic IR coverage to the Windows GitHub Actions
  conformance lane, with local build and execution smoke available from the same
  runner.

## Milestone 3: Standard Library Hardening

Goal: make the stable standard library small, documented, and testable.

Stable-core candidates:

- `std`
- `io`
- `str`
- `math`
- `time`
- `vec`
- `arena`

Beta candidates:

- `net`
- `tls`
- `tezzserve`
- `tezzapi`
- `tezzdb`
- `tezzdbql`
- GUI host modules

Experimental candidates:

- `gpu`
- `npu`
- `tensor`
- `nn`
- `llm`
- `tokenizer`
- `tts`
- `stt`
- `kernel`
- `os`
- `arduino`
- `raspi`

Hardening rules:

- Every stable public function must have a signature, behavior note, example,
  and failure behavior.
- Runtime-backed modules must state whether they use a real backend, CPU
  fallback, or stub.
- The default prelude should stay convenient but not silently import unstable
  experimental modules forever.
- Stable modules should have smoke tests.

Near-term stdlib optimization:

1. Create a module inventory table.
2. Add docs for stable-core modules first.
3. Add examples for file IO, strings, math, vectors, and time.
4. Add platform notes for networking, TLS, GUI, GPU, and NPU.
5. Split large prelude behavior into `std` and a future `std.full` or
   `std.experimental` path if needed.

## Milestone 4: Developer Experience

Goal: make TezzNative feel good before users know it is young.

Compiler diagnostics:

- Include file, line, column, and source snippet.
- Include expected vs actual type.
- Include one actionable help message when possible.
- Keep diagnostics deterministic for snapshot testing.

Tooling:

- `tezzc fmt` must preserve meaning and be idempotent.
- `tezzc lint` should support rule IDs and disable comments.
- VS Code snippets must match supported syntax only.
- LSP should prioritize diagnostics, hover type info, go-to-definition, and
  completion for imports/functions.

First examples:

- Hello world.
- CLI args.
- File read/write.
- HTTP request.
- HTTP server.
- C extern call.
- Native executable build.
- TezzDB small database.

Adoption gate:

- A new user can install, run, check, build, and read errors without needing
  private knowledge of the repo.

## Milestone 5: Ecosystem And Package Trust

Goal: give users confidence that projects can be shared and reproduced.

Package manager requirements:

- `tezz init`
- `tezz add`
- `tezz remove`
- `tezz update`
- `tezz lock`
- `tezz publish`
- `tezz test`
- `tezz build --release`

Registry requirements:

- Semantic versions.
- Lockfile checks.
- Package checksums.
- Package metadata validation.
- Docs generated from package source.
- Example and test requirements for first-party packages.

First-party package targets:

- JSON.
- CLI argument parser.
- Logging.
- Config file support.
- Regex.
- SQLite binding.
- HTTP client/server polish.
- Testing assertions.
- Benchmark helpers.

## Milestone 6: Python Bridge Strategy

Goal: compete with Python by integrating with Python first.

The fastest adoption path is not "replace Python today." It is:

> Keep Python for orchestration, use TezzNative for native hot paths.

Target command:

```bash
tezzc pyext module.tn
```

Required capabilities:

- Generate Python extension module wrappers.
- Map primitive TezzNative types to Python objects.
- Pass buffers safely for numeric/string workloads.
- Provide clear ownership rules for returned memory.
- Include examples for speeding up loops, parsers, and numeric kernels.

Success metric:

- A Python developer can accelerate a hot function without writing C.

## Milestone 7: C Replacement Strategy

Goal: earn trust from C developers with exact layout and ABI behavior.

Required work:

- Add integer width types: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`,
  `u64`.
- Document struct layout and alignment.
- Add packed/aligned struct support if needed.
- Add ABI tests for common C signatures.
- Make `cheader`, `abidump`, and `abiverify` part of CI.
- Add examples for calling C and being called from C.
- Improve freestanding documentation and build flow.

Success metric:

- A C library author can predict binary layout without guessing.

## Milestone 8: Benchmarks And Performance Proof

Goal: publish honest performance data.

Benchmark against:

- Python
- C
- Go
- Rust
- Node.js

Benchmark categories:

- Startup time.
- Compile time.
- Binary size.
- Memory usage.
- File read/write.
- String processing.
- JSON parsing.
- HTTP server throughput.
- Numeric loops.
- Matrix math where backend support is real.

Benchmark rules:

- Publish hardware, OS, compiler flags, and exact versions.
- Include source code for every benchmark.
- Do not hide losing results.
- Separate bytecode mode from native mode.
- Separate real GPU/NPU backend results from fallback results.

## Milestone 9: Security And Release Engineering

Goal: make releases reproducible and safer to install.

Required work:

- Release checklist.
- Artifact checksums.
- Signed release manifests.
- Installer verification.
- Dependency lock verification.
- Vulnerability reporting policy.
- Minimal telemetry policy.
- Crash/error report privacy notes.

Release gate:

- Every public binary has version metadata, checksum, and release notes.
- Site download pages and GitHub releases show the same version.
- Install scripts fail closed when checksums do not match.

## CI Matrix

Minimum CI before claiming a stable release:

| Job | Purpose |
| --- | --- |
| markdown | README and docs sanity |
| stdlib-check | Check stable and beta `.tn` modules |
| parser-tests | Syntax conformance |
| typecheck-tests | Semantic conformance |
| diagnostics-tests | Error snapshot stability |
| native-win-x64 | Windows native smoke |
| native-linux-x64 | Linux native smoke |
| abi-tests | Header/layout/API verification |
| package-tests | Manifest and lockfile behavior |

## Definition Of Done

A change is done when:

- It has a test or a documented reason why a test is not practical yet.
- It does not expand public claims beyond verified behavior.
- It updates docs when public behavior changes.
- It fails clearly on unsupported platforms.
- It keeps stable, beta, and experimental boundaries intact.

## Immediate Next 10 Tasks

1. Add a tracked conformance test directory.
2. Add parser success/failure tests.
3. Add type-checker success/failure tests.
4. Add diagnostic snapshots for common mistakes.
5. Add a stable stdlib module inventory.
6. Add native smoke tests for hello, math, strings, loops, and structs. Started:
   hello, math/loops, and structs are now covered.
7. Add an ABI layout test document and starter cases.
8. Add a platform support matrix.
9. Add a benchmark harness skeleton.
10. Publish the roadmap and stability pages on GitHub and tn.tezzcorp.com.

## Long-Term Release Gates

TezzNative should only claim broad replacement readiness when:

- The stable core has conformance tests.
- Native x86_64 Windows and Linux builds pass smoke tests.
- Stable stdlib modules have docs and examples.
- Package install/update/lock behavior is reproducible.
- C ABI layout is tested.
- Python extension interop exists or has a clear public milestone.
- Benchmarks are public and repeatable.

Until then, the public message should stay focused:

> TezzNative is a practical native language for Python-readable tools,
> automation, C interop, and systems experiments, with a rapidly hardening core.

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

Status: completed for the current public surface.

Goal: make the public project story accurate, restrained, and useful.

Delivered:

- Replaced broad marketing claims with an accurate capability map.
- Added public stability documentation.
- Added this optimization roadmap.
- Marked GPU and NPU modules as experimental surfaces.
- Corrected public metadata and duplicated manifest entries.
- Added the initial platform support matrix.
- Added the initial standard library maturity inventory.
- Added public conformance, C ABI, benchmark, release-engineering, telemetry,
  and trust-baseline documents that tie claims to evidence.
- Published website documentation pages for stability, roadmap, conformance,
  C ABI, benchmarks, and the public trust baseline.
- Published SDK release manifests and checksums so download/install claims can
  be verified independently.

Exit gate:

- GitHub README describes the real 1.1.0 state.
- Website has public stability and roadmap pages.
- Stable, beta, and experimental labels are visible to new users.
- Public replacement claims are bounded by `docs/TRUST_BASELINE.md`.

## Milestone 1: Conformance And Correctness Harness

Status: completed for the current stable-core surface.

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

Delivered:

- Added the public `tests/conformance` corpus with stable-core valid and invalid
  cases for arithmetic, control flow, structs, type mismatches, and unknown
  names.
- Added diagnostic snippet checks for the first invalid conformance cases.
- Added Windows and POSIX conformance runners.
- Added a stable stdlib import smoke fixture for `std`, `io`, `str`, `math`,
  `time`, `vec`, and `arena`.
- Expanded valid stable-core coverage for fixed arrays, indexing,
  `sizeof`/`alignof`, and unsafe pointer/address-of workflows.
- Expanded invalid and diagnostic-snippet coverage for unsafe address-of,
  unknown struct fields, named unknown values/modules/functions, and wrong
  function arity.
- Added first-class parser valid/invalid suites for comments/literals, nested
  blocks, struct/fixed-array syntax, bad indentation, missing block markers,
  and unterminated strings.
- Added first-class typecheck valid/invalid suites for function return/call
  flow, pointer-array roundtrip, struct value flow, array index type mismatch,
  return mismatch, and struct field assignment mismatch.
- Reworked Windows and POSIX runners to execute stable-core, parser,
  typecheck, diagnostics, and stdlib suites with deterministic suite-qualified
  output and `CONFORMANCE_SUMMARY passed=26 failed=0`.
- Added `docs/CONFORMANCE.md` describing the suite contract, commands, and
  rules for adding new cases.

## Milestone 2: Native Backend Reliability

Status: completed for the current Windows/Linux x64 surface.

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
- Added the POSIX native smoke runner:
  `tests/conformance/run-native-smoke.sh`.
- Added native executable smoke cases for hello output, loop/math lowering,
  deterministic `math` module helpers, string utilities and transforms, file
  read/write and line wrappers, portable path helpers, vector/arena allocation,
  and struct array field access.
- Promoted native smoke from advisory syntax coverage to hosted Windows and
  Linux execution gates.
- Fixed the shared x64 register allocation surface so Linux ELF output no
  longer keeps live values in `RDI`/`RSI` across calls.
- Fixed Linux/macOS native allocator lowering so `malloc(size)` calls the
  Tezz allocator ABI with the requested size instead of the Windows
  `VirtualAlloc` argument shape.
- Hardened Linux/macOS native `fread`/`fwrite` guard jumps so null and
  zero-length calls return deterministically.
- Reworked `io.File` line wrappers to use the guarded byte IO path instead of
  backend-specific line helpers, making read/write-line behavior portable across
  the Windows and Linux x64 native targets.
- Reworked `io.file_size_bytes` to use the portable `fopen`/`fseek`/`ftell`
  path instead of target-specific file-size lowering, and added native smoke for
  BigFile chunk reads plus StreamWriter buffered writes across buffer
  boundaries.
- Added native smoke for file exists/delete/rename and directory
  exists/make/remove workflows, with null-guarded public wrappers.
- Wired Linux ELF native filesystem lifecycle calls to syscall shims and moved
  Windows x64 native `remove`/`rename` lowering onto C-runtime return semantics.
- Confirmed direct-native directory enumeration remains a backend parity gap;
  runtime-backed directory listing/glob is hardened separately under the stdlib
  gate instead of being promoted as native-complete.
- Hardened direct-native `list_dir`, `list_dir_recursive`, `glob`, and
  `proc_out` fallbacks so unsupported OS-backed calls return `null` instead of
  a synthetic newline string.
- Added Linux x64 direct-native `dir_list` using the ELF syscall shim layer and
  promoted it behind a Linux-only native smoke gate; recursive directory
  listing and glob were later bridged through the native-smoke-gated stdlib
  helpers, and process-output capture now has Windows/Linux x64 parity.
- Added Windows x64 direct-native `dir_list` using `FindFirstFileA`/
  `FindNextFileA`/`FindClose`, and replaced the public `io.glob_list` wrapper
  with a portable stdlib implementation backed by `dir_list`; both are now
  native-smoke gated.
- Replaced public `io.dir_list_rec`/walk helpers with a portable stdlib
  implementation backed by the native-smoke-gated `dir_list`, and added
  Windows/Linux native executable coverage for recursive discovery.
- Bridged raw direct-native `list_dir_recursive` and `glob` calls to the same
  stdlib helper implementations loaded through the production prelude, with
  null-guard and positive raw-builtin smoke coverage.
- Added Windows x64 direct-native `proc_run`/`proc_out` lowering through the C
  runtime with bounded output capture and a Windows-only native smoke gate;
  added Linux x64 ELF syscall-backed `proc_run`/`proc_out` using
  fork/execve/wait4 and bounded pipe capture, with a Linux-only native smoke
  gate.
- Hardened `time.date_local()` with strict date-shape validation and
  Windows/Linux process-backed local-time formatting fallback, and promoted it
  into the native time smoke gate.
- Hardened `io.path_join_p` to use a single allocation/copy path and tightened
  `io.path_norm_p` pointer guards so portable path helpers pass native smoke on
  Windows and Linux x64.
- Added a Linux x64 ELF syscall-backed `net` bridge for IPv4 loopback TCP:
  socket, bind, listen, connect, accept, send, recv, close, and network
  constants now lower through direct-native stubs and are covered by a
  Linux-only loopback send/recv smoke test.
- Added Windows x64 direct-native `net` socket parity through the PE import
  table and Winsock adapters for WSA startup/cleanup, socket, bind, listen,
  connect, accept, send, recv, close, blocking mode, and socket timeouts. A
  Windows-only loopback smoke gate now validates bidirectional TCP send/recv.
- Added native smoke gates for 8-argument call/stack-argument handling on
  Windows/Linux x64, covering integer, string, and nested-call argument
  patterns that are common in stdlib service APIs.
- Added shared direct-native IPv4 literal host parsing for Windows/Linux x64
  `net.bind` and `net.connect` lowering. A new smoke gate proves invalid remote
  literal binds fail while `127.0.0.1` and `0.0.0.0` binds succeed; DNS-backed
  socket names and public-network HTTP remain the next networking gates.
- Normalized `localhost` in the public `net` module before backend socket calls
  so `net.connect`, `net.bind`, `tcp_connect`, `tcp_listen`, and `udp_connect`
  behave consistently across direct-native Windows/Linux x64. Native smoke now
  gates mixed-case localhost bind/connect plus TCP send/recv and UDP connect.
- Added an HTTP response reader that stops on `Content-Length` or completed
  chunked framing instead of waiting for peer close/timeout. `tcp_request` now
  uses this path, `Transfer-Encoding` token matching handles comma-separated
  values, and native smoke gates keep-alive fixed-length and chunked responses.
- Added `docs/NATIVE_BACKEND.md` as the public backend feature matrix and
  reliability contract for the current primary targets.
- Added Windows/Linux native reliability runners that build focused fixtures
  twice, compare executable SHA-256 hashes, execute host-safe outputs, and
  assert unsupported `buildexe --target` names fail closed without emitting an
  artifact.
- Promoted native reliability into hosted Windows and Linux conformance CI.

Completed exit gate:

- Native executable output is reproducible for focused stable fixtures on
  Windows x64 and Linux x64.
- Backend failures for unknown targets produce clear errors instead of silent
  fallback.
- Unsupported targets fail explicitly and are documented as outside the current
  primary release promise.

## Milestone 3: Standard Library Hardening

Status: completed for the current stable-candidate stdlib slice.

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

Started:

- Added native executable smoke for `str` helpers, file read/write through C
  runtime IO, portable `io` path helpers, deterministic `math` helpers, `vec`
  integer vectors, and `arena` allocation/reset workflows.
- Hardened `io.File` wrapper ownership/failure behavior so failed opens return
  null and null handles do not reach low-level runtime calls; native smoke now
  gates wrapper open/write/read/write-line/read-line/flush/seek/tell/close plus
  null-read and EOF guards.
- Hardened `StreamWriter` flush/close behavior so invalid handles mark errors
  and close reports flush or `fclose` failures.
- Hardened `io.file_exists`, `io.dir_exists`, `io.file_delete`,
  `io.file_rename`, `io.dir_make`, `io.dir_remove`, `io.dir_list`,
  `io.dir_list_rec`, and `io.glob_list` null/failure behavior.
- Hardened VM/runtime directory enumeration to return deterministic sorted
  listings, sorted recursive walks, and glob results built from the same
  listing path; added a runtime gate for listing contents, ordering, recursive
  discovery, glob inclusion/exclusion, and cleanup.
- Fixed the runtime-hardening freestanding manifest so hosted `say` examples do
  not appear in the freestanding-ok boundary list.
- Reworked `io.path_join_p` to avoid intermediate ownership ambiguity and
  reduce allocations.
- Reworked `io.path_norm_p` guarded pointer reads so native code never touches
  a buffer before its bounds condition has passed.
- Reworked `str.str_replace_first`, `str.str_replace`, and `str.str_pad_int`
  to use direct exact-size allocation/copy paths that are deterministic under
  both Windows PE and Linux ELF native codegen.
- Removed the demo `main` from `lib/math.tn` so `math` stays a library-only
  import surface.
- Closed the native `time` date-format gaps: Windows/Linux x64 now gate clock,
  sleep, UTC date-format, and local date-format helpers in native smoke.
- Hardened deterministic `net` helpers: URL path/query handling no longer
  duplicates query strings, scheme security/default-port checks use exact
  case-insensitive schemes, HTTP header lookup is case-insensitive, LF-only
  HTTP buffers are accepted, reason phrases preserve ordinary `r` characters,
  IPv4 octets are range checked, and query strings with fragments are handled.
  Native smoke now gates URL, DNS endpoint, HTTP parser, route, auth/cookie,
  and chunked response decoding helpers on Windows and Linux x64.
- Added a Linux x64 `net` loopback smoke gate that creates a listener,
  connects a client, accepts the server peer, and validates bidirectional
  `ping`/`pong` TCP send/recv through the direct-native backend.
- Added the matching Windows x64 `net` loopback smoke gate through Winsock PE
  imports, closing the first direct-native socket parity slice.
- Added Windows/Linux native smoke for socket timeout/blocking options, manual
  local HTTP request/read/response flow, and the higher-level
  `http_server_serve_route_once` route helper. `http_write_response` and the
  route helper now pass a concrete empty header string for the no-extra-headers
  case, avoiding nullable stack-argument behavior in nested native calls.
- Added Windows/Linux native smoke for IPv4 literal socket bind host handling
  so direct-native `net.bind` no longer collapses every host string to loopback.
- Added Windows/Linux native smoke for public localhost socket wrappers across
  bind, TCP connect, and UDP connect. DNS-backed sockets and public-network HTTP
  execution remain the next networking hardening gates.
- Added Windows/Linux native smoke for keep-alive HTTP response reads covering
  fixed `Content-Length`, chunked bodies with extensions/trailers, and
  comma-separated `Transfer-Encoding` tokens.
- Added `docs/STDLIB_CORE.md` as the public stable-candidate stdlib contract
  for ownership, failure behavior, platform notes, and verification commands.
- Hardened `math.divmod` null-output guards, `math.smoothstep` equal-edge
  behavior, and `math.atan2` quadrant handling; added native edge gates for
  divide-by-zero/null-output, smoothstep, inverse trig, and quadrant behavior.
- Hardened `str.str_replace_first` for empty needles so it returns a duplicate
  of the source instead of injecting the replacement at offset zero.
- Hardened `vec.vec_reserve` and `vec.vec_fill` so null vectors fail with
  `-1`, while zero-count fills remain a no-op for valid vectors.
- Hardened `arena.arena_alloc_aligned` to reject non-power-of-two alignments
  and `arena.arena_release` to reject future marks beyond current usage.
- Added native edge fixtures for stable-candidate stdlib math and collections
  behavior across Windows/Linux x64:
  `stdlib_math_edges.tn` and `stdlib_collections_edges.tn`.

Completed exit gate:

- Stable-candidate stdlib modules have public ownership/failure/platform rules
  in `docs/STDLIB_CORE.md`.
- `std`, `io`, `str`, `math`, `time`, `vec`, and `arena` have import or native
  smoke coverage; math/string/vector/arena edge behavior is now native gated.
- The standard library maturity inventory and public status text are
  synchronized with the gated surface.

## Milestone 4: Developer Experience

Status: completed for the current first-user workflow surface.

Goal: make TezzNative feel good before users know it is young.

Compiler diagnostics:

- Include file, line, column, and source snippet.
- Include expected vs actual type.
- Include one actionable help message when possible.
- Keep diagnostics deterministic for snapshot testing.

Started:

- Replaced generic untyped RHS failures in value contexts with named
  `unknown name` diagnostics.
- Named unknown module and module-function call failures, so import/call
  mistakes identify the exact missing symbol.
- Expanded wrong-arity diagnostics for normal and module calls with expected
  and actual argument counts while keeping deterministic snippet gates.
- Added deterministic `help:` lines for common unknown-name, unknown-module,
  wrong-arity, type-mismatch, unsafe, and missing-block-marker errors.
- Added the public Windows/Linux DX runner:
  `tests/conformance/run-dx.ps1` and `tests/conformance/run-dx.sh`.
- Added DX fixtures for actionable diagnostics, formatter idempotence, lint
  rule IDs, and lint suppression behavior.
- Added curated first examples under `examples/dx` for hello, CLI-style flags,
  file read/write, HTTP parsing, route matching, C extern calls, native builds,
  and a beta TezzDB starter.
- Added `docs/DEVELOPER_EXPERIENCE.md` with the DX contract and commands.
- Promoted the TezzNative LSP source and VS Code snippets into the DX gate, and
  removed aspirational default snippets that referenced experimental module
  flows without matching public examples.
- Added the DX gate to hosted Windows and Linux conformance CI.
- Included examples and DX conformance files in the packaged SDK manifest.

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

Completed exit gate:

- `DX_SUMMARY passed=19 failed=0` on Windows and Linux for the current SDK.
- Public examples are checkable, `hello.tn` runs, and `native_build.tn` builds
  and executes through `buildexe --verify`.
- Editor snippets, LSP source, formatter, linter, and actionable diagnostics
  are part of the public conformance story.

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

Status: completed for the current starter ABI surface.

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

Started:

- Added `tests/conformance/run-abi.ps1`.
- Added `tests/conformance/run-abi.sh`.
- Added starter ABI fixtures for struct layout, pointer fields, fixed arrays,
  nested structs, mixed scalar fields, and extern C signatures.
- Added ABI conformance to GitHub Actions through `cheader` and `abidump`, with
  full local `abiverify` available from the same runner.
- Expanded ABI runner assertions on Windows and POSIX so header and dump checks
  cover alignment assertions, array fields, nested struct fields, by-value
  struct parameters, and pointer parameters.
- Fixed `abidump` field offsets so the ABI manifest records computed layout
  offsets instead of parser placeholder offsets.
- Promoted `abidump` to strict structured JSON with schema
  `tezznative.abi.v1`.
- Replaced brittle dump string checks with parsed JSON assertions for struct
  sizes, alignment, field offsets, field type shapes, extern return types, and
  parameter type shapes.
- Promoted Windows hosted ABI CI to full `abiverify`; Windows and Linux now
  both run `cheader`, `abidump`, and `abiverify` against the published SDK
  compiler.
- Added `docs/C_ABI.md` with the current layout contract, C type mapping,
  header/dump workflow, and C interop examples.

## Milestone 8: Benchmarks And Performance Proof

Status: completed for the current public benchmark surface.

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

Delivered:

- Added `benchmarks/run.ps1`.
- Added `benchmarks/run.sh`.
- Added source-visible TezzNative, Python, and C starter fixtures for a numeric
  loop benchmark.
- The harness records OS, architecture, PowerShell version, command, exit code,
  elapsed time, and binary size where available.
- Added CI check-only validation so public benchmark TezzNative sources stay in
  the supported syntax subset.
- Expanded the source-visible workload set to startup, numeric loop,
  string-scan, and binary file read/write.
- Added optional comparison fixtures for Python, C, Node.js, Go, and Rust.
- Upgraded the runners to emit schema-labeled CSV plus metadata JSON with
  command lines, exit codes, output hashes, timeout status, binary sizes, and
  peak working-set memory where the host exposes it.
- Separated TezzNative check, bytecode run, native build, and native run phases
  so compile time, runtime, and binary size are not mixed.
- Documented the public workload matrix, skipped-tool behavior, result schema,
  and publishing rules in `docs/BENCHMARKS.md`.

Still intentionally unclaimed:

- JSON parsing, HTTP throughput, matrix math, and GPU/NPU performance remain
  outside public benchmark claims until source-visible fixtures and backend
  correctness gates exist.

## Milestone 9: Security And Release Engineering

Status: completed for the current release surface.

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

Delivered:

- Added `SECURITY.md` with private vulnerability reporting and supported
  release-surface policy.
- Added `docs/RELEASE_ENGINEERING.md` with the public artifact list,
  manifest commands, installer checksum rule, and release checklist.
- Added `docs/TELEMETRY_PRIVACY.md` documenting that compiler/runtime use is
  local and that portal install/update events are best-effort and minimal.
- Added `tools/release/build_release_manifest.ps1` and
  `tools/release/verify_release_manifest.ps1` for SHA-256 manifest generation
  and verification.
- Added a GitHub `release-security` workflow that verifies a generated manifest
  and proves tampered artifacts fail verification.
- Hardened the Windows GitHub conformance download path to use bounded
  PowerShell HTTPS downloads and manifest/sidecar SHA-256 verification.
- Hardened Windows and Linux install scripts on `tn.tezzcorp.com` so SDK
  archives are checked against published `.sha256` files before extraction.
- Published `download/release_manifest.json` and
  `download/release_manifest.json.sha256` beside the SDK archives.

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
5. Add a stable stdlib module inventory. Done for the initial public inventory;
   smoke coverage started with `tests/conformance/stdlib/stable_modules.tn`.
6. Add native smoke tests for hello, math, strings, loops, structs, file IO,
   portable path helpers, vectors, arenas, and time. Done for the initial gate:
   deterministic math/string/io wrapper/path/time/vec/arena workflows are now
   execution-gated on Windows and Linux.
7. Add an ABI layout test document and starter cases. Started with
   `tests/conformance/run-abi.ps1`, `tests/conformance/run-abi.sh`, and
   `tests/conformance/abi/starter_abi.tn`.
8. Add a platform support matrix.
9. Add a benchmark harness skeleton. Done: `benchmarks/run.ps1` with TezzNative,
   Python, and C starter fixtures.
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

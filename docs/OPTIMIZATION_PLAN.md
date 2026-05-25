# TezzNative Optimization Plan

This plan focuses on making TezzNative credible, testable, and useful before
expanding the feature surface further.

## Principle

Prioritize trust over feature count.

The repository already has a wide standard library and ambitious runtime
surfaces. The next optimization step is to make the core language, compiler,
stdlib, and deployment story predictable.

## Phase 1: Public Trust Layer

Status: started.

- Replace broad marketing claims with a clear capability map.
- Publish stability labels for language and stdlib surfaces.
- Keep experimental modules visible but clearly marked.
- Make the GitHub README accurate enough for first-time users.
- Keep version metadata consistent across `version.json`, `tezz.mod`, docs, and
  website release pages.

## Phase 2: Compiler Correctness

- Add parser tests for valid and invalid syntax.
- Add type-checker tests for calls, assignments, casts, arrays, structs, and
  unsafe operations.
- Add diagnostics snapshot tests so error messages do not regress silently.
- Add IR verifier tests for labels, calls, loads, stores, conversions, and
  returns.
- Add native executable smoke tests for hello world, integer math, strings, file
  IO, and simple structs.

## Phase 3: Native Backend Quality

- Make x86_64 Windows and Linux the first production-grade targets.
- Track backend support by instruction/op instead of broad platform claims.
- Add register allocation stress tests.
- Add constant folding, dead code elimination, and simple inlining benchmarks.
- Keep bytecode mode as the compatibility path while native codegen matures.

## Phase 4: Standard Library Hardening

- Split documentation into stable, beta, and experimental groups.
- Add examples for every stable public module.
- Add module smoke tests that can run in CI.
- Document runtime fallback behavior for network, TLS, GPU, NPU, and GUI APIs.
- Reduce heavy default imports over time by offering a smaller stable prelude.

## Phase 5: Developer Experience

- Improve `tezzc` diagnostics with actionable help text.
- Expand `fmt` and `lint` coverage.
- Improve VS Code snippets to match only currently supported syntax.
- Add "first 10 minutes" examples: CLI, file IO, HTTP request, HTTP server,
  C interop, and native executable.

## Phase 6: Ecosystem And Adoption

- Stabilize package metadata and lockfile behavior.
- Add package checksum verification.
- Create first-party packages for JSON, CLI args, logging, config, regex, and
  SQLite bindings.
- Add Python extension interop as a bridge instead of positioning TezzNative as
  a direct Python replacement from day one.

## Phase 7: Benchmarks

Publish honest benchmarks against Python, C, Go, Rust, and Node.js:

- startup time
- compile time
- binary size
- memory usage
- file IO
- string processing
- JSON parsing
- HTTP server throughput
- numeric loops

The goal is not to claim TezzNative wins everywhere. The goal is to show where
it is already strong and where optimization work remains.

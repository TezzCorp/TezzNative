# TezzNative Stability Map

This document defines the public stability labels used by TezzNative. The goal
is to make the language easier to trust: users should know which surfaces are
ready for real projects and which surfaces are still experimental.

## Stability Labels

| Label | Meaning |
| --- | --- |
| Stable | Intended for normal use. Breaking changes require a clear migration path. |
| Beta | Usable, but behavior or diagnostics may still change between releases. |
| Experimental | Available for testing and design feedback. APIs may change or be removed. |
| Internal | Implementation detail. Not part of the public compatibility contract. |

## Stable Core

These features are the first compatibility target:

- Source files using indentation-based blocks
- `fn`, `let`, `const let`, `struct`, `enum`, `typedef`
- `if`, `else`, `while`, C-style `for`, `switch`, `break`, `continue`, `ret`
- Primitive aliases such as `int`, `float`, `char`, `str`, and `void`
- Arrays, pointers, casts, indexing, field access, `sizeof`, and `alignof`
- Module imports from the local project and standard library
- `tezzc check`, `tezzc run`, and bytecode-backed development workflows

The stable-core conformance gate now includes fixed arrays/indexing,
`sizeof`/`alignof`, struct-field diagnostics, function-arity diagnostics, and
unsafe pointer/address-of coverage.

## Beta Surfaces

These surfaces are useful today but need more conformance tests:

- Native executable generation
- C ABI interop, `extern fn`, C header generation, ABI dump/verify with starter
  layout coverage for scalar mixes, arrays, pointers, and nested structs
- Borrow/mutability diagnostics
- `fmt` and `lint`
- `io`, `str`, `math`, `vec`, `arena`, `time`; imports plus selected native
  executable smoke for raw/wrapped/line/stream file IO, directory lifecycle,
  direct `dir_list`, raw/public recursive listing and glob, portable paths, math
  helpers, string transforms, vectors, arenas, process run/output capture, and
  `time` clock/sleep/UTC-date helpers are gated across both primary x64
  targets. Local timezone formatting remains preview. VM/runtime gates also
  cover sorted recursive directory listing and raw glob filters.
- `net`, `tls`, `tezzserve`, `tezzapi`
- `tezzdb` and `tezzdbql`
- GUI modules on supported host platforms

## Experimental Surfaces

These are intentionally not part of the stable compatibility contract yet:

- `gpu` and `npu`
- `tensor`, `nn`, `llm`, `tokenizer`, `tts`, `stt`
- `kernel`, `os`, `arduino`, `raspi`
- Cross-target GPU lowering
- Bare-metal build flows
- Any runtime path that depends on optional native backends

Experimental modules should be imported directly by projects that accept that
risk. They should not be treated as guaranteed production APIs.

## Compatibility Rules

- Stable APIs should preserve source compatibility within the same major API.
- Beta APIs may change, but changes should be documented.
- Experimental APIs may change without migration guarantees.
- Runtime-backed modules must document whether they use a real backend, a CPU
  fallback, or a stub on each platform.

## Near-Term Hardening Checklist

- Add parser and type-checker snapshot tests.
- Continue expanding ABI layout tests beyond the starter structs, arrays,
  pointers, and function signatures.
- Add native executable stress tests for Windows and Linux x86_64 beyond the
  current hello, loop/math, math-module, string, struct, raw/wrapped/line/stream
  file IO, directory lifecycle, recursive listing, portable path, vector,
  arena, process, and time smoke.
- Add local timezone formatting parity after the current UTC-date smoke gates.
- Add module-level stdlib checks for stable and beta modules.
- Add docs for every stable public function.
- Publish benchmark and platform support matrices.

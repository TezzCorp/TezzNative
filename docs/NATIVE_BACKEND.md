# TezzNative Native Backend Reliability

This document defines the current native backend promise. It keeps the public
target story narrow enough to test and broad enough to be useful for early CLI,
automation, utility, and C-interop workflows.

## Primary Gate

The current primary native targets are:

| Target | Build command target | Artifact | Execution gate |
| --- | --- | --- | --- |
| Windows x64 | `x86_64` | PE/COFF executable | GitHub Actions `windows-2022` plus local smoke |
| Linux x64 | `linux` | ELF executable | GitHub Actions `ubuntu-22.04` plus Debian/WSL smoke |

These targets are the only native executable targets that should be described
as primary today.

## Reliability Gates

Native backend reliability is checked by:

| Gate | Command | Purpose |
| --- | --- | --- |
| Native smoke | `tests/conformance/run-native-smoke.*` | Build, verify, execute, and compare output for native feature coverage. |
| Native reliability | `tests/conformance/run-native-reliability.*` | Build deterministic native artifacts twice and compare SHA-256 output. |
| Unsupported target check | Included in native reliability | Ensure unknown targets fail closed and do not emit an artifact. |
| Release manifest | `tools/release/verify_release_manifest.ps1` | Verify published SDK artifacts and checksums. |

The native reliability runner currently checks deterministic executable output
for focused host-safe fixtures:

- `hello.tn`
- `loop_math.tn`
- `many_args.tn`
- `many_args_nested.tn`
- `many_args_strings.tn`
- `math_module.tn`
- `string_ops.tn`
- `string_transforms.tn`
- `struct_array.tn`
- `collections_memory.tn`

These fixtures cover entry-point lowering, integer loops, arithmetic, stack
arguments, nested calls, string globals/helpers, struct arrays, vectors, and
arena allocation without depending on filesystem, socket, clock, or process
timing.

## Covered Backend Features

| Area | Windows x64 | Linux x64 | Notes |
| --- | --- | --- | --- |
| Executable format | Gated | Gated | PE/COFF and ELF verification run with `--verify`. |
| Entrypoint/exit | Gated | Gated | Hello/native output smoke. |
| Integer arithmetic and loops | Gated | Gated | Loop/math and benchmark fixture checks. |
| Fixed-width integer loads | Gated | Gated | `i8/i16/i32` signed extension, `u8/u16/u32` zero extension, struct fields, arrays, and `u32` indexing are smoke gated. |
| Stack arguments | Gated | Gated | 8-argument integer/string/nested-call fixtures. |
| Struct/array fields | Gated | Gated | Struct-array native fixture. |
| Globals and string data | Gated | Gated | String ops/transforms and hello output. |
| Raw and wrapped file IO | Gated | Gated | Native smoke covers file, line, stream, and failure guards. |
| Directory lifecycle/list/glob | Gated | Gated | Direct `dir_list`, recursive listing, and glob helpers are smoke gated. |
| Process run/output | Gated | Gated | Platform-specific process smoke fixtures. |
| Time/date helpers | Gated | Gated | Clock, sleep, UTC date, and local date helpers are smoke gated. |
| TCP loopback sockets | Gated | Gated | Local TCP send/recv, options, localhost, and route helpers are smoke gated. |
| Keep-alive HTTP response reads | Gated | Gated | Fixed length and chunked framing fixtures are smoke gated. |
| DNS-backed sockets | Beta gap | Beta gap | Endpoint parsing is gated; real DNS socket execution is not promoted yet. |
| Public-network HTTP | Beta gap | Beta gap | Local loopback is gated; public network execution is not promoted yet. |
| macOS x64 | Planned | Planned | Backend code exists but no hosted release gate yet. |
| ARM64 targets | Experimental/Planned | Planned | Not a primary release promise. |

## Failure Rules

- Unsupported `buildexe --target` names must exit non-zero.
- Unsupported targets must not leave an output executable behind.
- Backend failures should include the failing target or backend operation in the
  diagnostic text.
- Unknown or future targets must not silently fall back to Windows x64 or Linux
  x64 behavior.
- Native reproducibility claims require byte-identical executable hashes from
  repeated builds of the same fixture with the same compiler and target.

## Current Status

Milestone 2 is complete for the current Windows/Linux x64 surface when:

- Native smoke passes on Windows x64 and Linux x64.
- Native reliability passes on Windows x64 and Linux x64.
- GitHub Actions runs both gates.
- Public platform/stability docs list primary targets and beta gaps.
- Published SDKs include the reliability runners and this backend matrix.

# TezzNative Platform Support

This matrix separates verified support from planned or experimental targets.
It should be updated whenever compiler, runtime, installer, or stdlib behavior
changes.

## Support Labels

| Label | Meaning |
| --- | --- |
| Primary | First-class target for current hardening and smoke tests. |
| Preview | Usable for testing, but not yet a release gate. |
| Experimental | Backend or runtime work exists, but behavior may be incomplete. |
| Planned | Design target with no public compatibility promise yet. |

## Compiler And Runtime

| Target | Status | Notes |
| --- | --- | --- |
| Windows x64 | Primary | Main packaged SDK and installer target. Native executable flow is the first production hardening target. |
| Linux x64 | Primary/Beta | Static SDK compiler archive exists to avoid hosted-runner glibc drift. Stable-core, ABI, benchmark fixture checks, and native executable smoke pass under WSL and GitHub Actions. |
| macOS x64 | Planned | Listed as a target in metadata, but needs packaged toolchain validation. |
| Linux ARM64 | Planned | Listed as a target in metadata, but not a release gate yet. |
| macOS ARM64 | Planned | Listed as a target in metadata, but not a release gate yet. |
| Windows x86 | Experimental | Backend status exists, but not part of the main release promise. |
| Windows ARM64 | Experimental | Verify-only or limited paths should be documented before public promotion. |

## Module Families

| Area | Windows x64 | Linux x64 | macOS | Notes |
| --- | --- | --- | --- | --- |
| Core language | Primary | Primary | Planned | Stable-core conformance runs on Windows and Linux SDKs. |
| Bytecode run | Primary | Preview | Planned | Compatibility path while native backend matures. |
| Native executable | Primary/Beta | Primary/Beta | Planned | Hello, loop/math, math-module, string, string-transform, struct-array, raw/wrapped/line/stream file IO, directory lifecycle, direct `dir_list`, raw/public recursive listing and glob, portable path, vector, arena, process run/output, time, deterministic net/HTTP parser, and Linux TCP loopback smoke tests pass on the claimed x64 targets. |
| Time/date runtime | Beta | Beta | Planned | `time` imports and native clock/sleep/UTC/local-date execution are gated on Windows/Linux x64. |
| IO/path/process | Beta | Beta | Planned | Raw file read/write, File wrapper open/write/read-line/write-line/flush/seek/tell/close, BigFile chunk reads, StreamWriter flush/close behavior, portable `file_size_bytes`, file delete/rename, directory exists/make/remove, EOF/null guards, portable path helpers, direct `dir_list`, raw/public recursive listing and glob, and `proc_run`/`proc_out` have native smoke coverage on Windows/Linux x64. |
| Networking | Beta | Beta | Planned | URL parsing, DNS endpoint helpers, HTTP parser/routing/auth/cookie utilities, chunked response decoding, and Linux x64 TCP loopback send/recv are smoke gated. Windows socket parity and live HTTP client/server tests are still needed. |
| TLS | Beta | Preview | Planned | Linux builds without OpenSSL development headers expose unsupported TLS stubs until linked with a TLS backend. |
| GUI | Beta | Experimental | Planned | Windows host modules are the clearest path today. |
| TezzDB | Beta | Preview | Planned | Needs database consistency and WAL tests. |
| GPU/NPU | Experimental | Experimental | Experimental | Backend availability must be reported explicitly. |
| OS/kernel | Experimental | Experimental | Experimental | Separate freestanding build flow required. |

## Release Gates

A target should not move to Primary until:

- `tezzc check` passes the stable conformance corpus.
- bytecode run smoke tests pass.
- native smoke tests pass where native support is claimed.
- stdlib stable module smoke tests pass.
- install and uninstall flows are tested.
- package checksums and version metadata are published.

## Immediate Improvements

1. Add CI jobs for Windows x64 and Linux x64.
2. Add Windows socket parity and live HTTP client/server smoke tests before
   promoting networking beyond Beta.
3. Publish exact binary names, hashes, and sizes for every download.
4. Add target-specific notes to docs and download pages.
5. Fail unsupported targets clearly instead of silently falling back.

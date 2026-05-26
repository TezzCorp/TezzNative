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
| Linux x64 | Primary/Beta | Static SDK compiler archive exists. Stable-core, ABI, benchmark fixture checks, and native executable smoke pass under WSL and GitHub Actions. |
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
| Native executable | Primary/Beta | Primary/Beta | Planned | Hello, loop/math, string, struct-array, file IO, and portable path executable smoke tests pass on Windows and Linux x64. |
| IO/path/process | Beta | Preview | Planned | File read/write and portable path helpers have native smoke coverage; OS-backed path/process behavior still needs platform-specific tests. |
| Networking | Beta | Preview | Planned | Socket and HTTP tests should be added. |
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
2. Add OS-backed path/process smoke tests after the current hello, math/loops,
   strings, structs, file IO, and portable path gate.
3. Publish exact binary names, hashes, and sizes for every download.
4. Add target-specific notes to docs and download pages.
5. Fail unsupported targets clearly instead of silently falling back.

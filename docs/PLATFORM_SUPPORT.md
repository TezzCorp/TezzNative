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
| Linux x64 | Preview | SDK archive exists. Native executable flow needs repeatable smoke tests before primary status. |
| macOS x64 | Planned | Listed as a target in metadata, but needs packaged toolchain validation. |
| Linux ARM64 | Planned | Listed as a target in metadata, but not a release gate yet. |
| macOS ARM64 | Planned | Listed as a target in metadata, but not a release gate yet. |
| Windows x86 | Experimental | Backend status exists, but not part of the main release promise. |
| Windows ARM64 | Experimental | Verify-only or limited paths should be documented before public promotion. |

## Module Families

| Area | Windows x64 | Linux x64 | macOS | Notes |
| --- | --- | --- | --- | --- |
| Core language | Primary | Preview | Planned | Parser/type checker tests should be platform-independent. |
| Bytecode run | Primary | Preview | Planned | Compatibility path while native backend matures. |
| Native executable | Primary/Beta | Preview/Beta | Planned | Requires native smoke tests per target. |
| IO/path/process | Beta | Preview | Planned | Needs platform-specific behavior tests. |
| Networking | Beta | Preview | Planned | Socket and HTTP tests should be added. |
| TLS | Beta | Preview | Planned | Must document runtime backend and certificate behavior. |
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
2. Add native smoke tests for hello, math, strings, loops, structs, and file IO.
3. Publish exact binary names, hashes, and sizes for every download.
4. Add target-specific notes to docs and download pages.
5. Fail unsupported targets clearly instead of silently falling back.

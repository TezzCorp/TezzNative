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
| Linux x64 | Primary/Beta | Static SDK compiler archive and direct compiler download are published to avoid hosted-runner glibc drift. Stable-core, ABI header/dump/verify checks, benchmark fixture checks, native executable smoke, and native reliability checks pass under WSL and GitHub Actions. |
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
| Native executable | Primary/Beta | Primary/Beta | Planned | Hello, loop/math, fixed-width integer truncation and signed/unsigned load extension, many-argument calls, math-module, stdlib math/collections edges, string, string-transform, struct-array, raw/wrapped/line/stream file IO, directory lifecycle, direct `dir_list`, raw/public recursive listing and glob, portable path, vector, arena, process run/output, time, deterministic net/HTTP parser, Windows/Linux TCP loopback, IPv4 literal socket bind hosts, localhost socket wrappers, keep-alive HTTP response reads, and local HTTP route smoke tests pass on the claimed x64 targets. Focused native fixtures are also byte-reproducibility gated on Windows/Linux x64, and unknown targets are fail-closed. |
| Python bridge scaffold | Beta | Beta | Planned | `tezzc pyext` emits CPython wrapper C, ABI declarations, setup metadata, ownership docs, and wrapped/skipped manifests for primitive returns and borrowed buffer parameters. The gate validates generated source on Windows/Linux; full Python packaging/runtime ownership compatibility remains a future promotion item. |
| Benchmark harness | Primary | Primary | Planned | Startup, numeric loop, string scan, and binary file IO fixtures are check-gated on Windows/Linux; optional Python, C, Node.js, Go, and Rust comparison fixtures run when local toolchains are available. |
| Time/date runtime | Beta | Beta | Planned | `time` imports and native clock/sleep/UTC/local-date execution are gated on Windows/Linux x64. |
| IO/path/process | Beta | Beta | Planned | Raw file read/write, File wrapper open/write/read-line/write-line/flush/seek/tell/close, BigFile chunk reads, StreamWriter flush/close behavior, portable `file_size_bytes`, file delete/rename, directory exists/make/remove, EOF/null guards, portable path helpers, direct `dir_list`, raw/public recursive listing and glob, and `proc_run`/`proc_out` have native smoke coverage on Windows/Linux x64. |
| Networking | Beta | Beta | Planned | URL parsing, DNS endpoint helpers, HTTP parser/routing/auth/cookie utilities, chunked response decoding, keep-alive `Content-Length`/chunked response reads, Windows/Linux x64 TCP loopback send/recv, IPv4 literal socket bind hosts, localhost TCP/UDP connect wrappers, socket timeout/blocking options, and local HTTP client/server route helpers are smoke gated. DNS-backed sockets and public-network HTTP tests are still needed. |
| Actor runtime | Beta foundation | Beta foundation | Planned | Local in-process actor systems, mailbox matching, supervisor restarts, node metadata with fail-closed remote sends, hot version tags, and OTP-style app helpers are native-smoke gated. Real scheduler-backed actors, node-to-node transport, and versioned module replacement are planned runtime gates. |
| TLS | Beta | Preview | Planned | Linux builds without OpenSSL development headers expose unsupported TLS stubs until linked with a TLS backend. |
| GUI | Beta | Experimental | Planned | Windows host modules are the clearest path today. |
| TezzDB | Beta | Preview | Planned | Needs database consistency and WAL tests. |
| GPU/NPU | Experimental | Experimental | Experimental | Backend availability must be reported explicitly. |
| OS/kernel | Experimental | Experimental | Experimental | Separate freestanding build flow required. |

## Release Gates

A target should not move to Primary until:

- `tezzc check` passes the stable conformance corpus.
- bytecode run smoke tests pass.
- native smoke and native reliability tests pass where native support is claimed.
- stdlib stable module smoke tests pass.
- install and uninstall flows are tested.
- package checksums and version metadata are published.
- release manifests verify every public SDK archive before install scripts
  extract them.

## Immediate Improvements

1. Add CI jobs for Windows x64 and Linux x64.
2. Add DNS-backed socket and public-network HTTP smoke tests before promoting
   networking beyond Beta.
3. Publish exact binary names, hashes, and sizes for every download.
4. Add target-specific notes to docs and download pages.
5. Add macOS and ARM64 hosted gates before promoting those targets.
6. Add scheduler, remote actor transport, and service-scale benchmarks before
   promoting actor runtime claims beyond Beta foundation.

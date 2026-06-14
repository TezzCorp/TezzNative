# TezzNative Standard Library Inventory

This inventory gives each public module an explicit maturity label. The goal is
to keep the standard library useful without letting experimental APIs weaken
trust in the stable core.

## Labels

| Label | Meaning |
| --- | --- |
| Stable Candidate | Suitable for near-term hardening and compatibility tests. |
| Beta | Useful today, but needs more tests and platform notes. |
| Experimental | API or runtime backend may change. |
| Internal/Tooling | Used by tooling, packaging, or specialized workflows. |

## Stable Candidates

| Module | Purpose | Next Hardening Step |
| --- | --- | --- |
| `std` | Common prelude and helpers | Import smoke is gated; keep imports predictable and consider separating experimental imports later. |
| `io` | Files, paths, streams, basic OS IO | Raw file read/write, File wrapper open/write/read-line/write-line/flush/seek/tell/close, BigFile chunk reads, StreamWriter flush/close behavior, portable `file_size_bytes`, file exists/delete/rename, directory exists/make/remove, failed-open/null guards, EOF behavior, portable path helpers, direct `dir_list`, raw/public recursive listing and glob, and process run/output capture are native-smoke gated on Windows/Linux x64. VM/runtime gates cover sorted recursive listing and raw glob filters. |
| `str` | String helpers | Native search/prefix/suffix plus trim/case/slice/replace/repeat/pad/parse smoke is gated; empty `str_replace_first` behavior is edge-gated. |
| `math` | Numeric helpers | Native integer, float, divmod, aggregate, dot-product, divide-by-zero/null-output, `smoothstep`, and quadrant `atan2` smoke is gated. |
| `time` | Time and sleep helpers | Import smoke plus native clock/sleep/UTC/local-date smoke are gated on Windows/Linux x64; ownership of `date_now` backend output remains backend-defined. |
| `vec` | Dynamic vector utilities | Native integer vector push/get/set/pop/free smoke is gated; reserve/fill null guards and reserve growth are edge-gated. |
| `arena` | Arena allocation helpers | Native allocation/alignment/strdup/mark/release/reset smoke is gated; wrapped buffers, invalid alignment, and future-mark release failures are edge-gated. |

## Beta Modules

| Module | Purpose | Next Hardening Step |
| --- | --- | --- |
| `net` | TCP, UDP, HTTP helpers | URL parsing, DNS endpoint helpers, HTTP parser/routing/auth/cookie utilities, chunked response decoding, keep-alive `Content-Length`/chunked response reads, Windows/Linux x64 TCP loopback send/recv, IPv4 literal socket bind host handling, localhost TCP/UDP connect wrappers, socket timeout/blocking options, manual local HTTP request/response, and route-once server helpers are native-smoke gated; add DNS-backed socket and public-network HTTP tests next. |
| `tls` | TLS runtime wrappers | Document backend policy and certificate behavior. |
| `tezzserve` | HTTP/server helpers | Add route, JSON, static file, and websocket smoke tests. |
| `tezzapi` | REST API framework | Add request/response validation examples. |
| `tezzdb` | Embedded database | Add transaction, index, WAL, and recovery tests. |
| `tezzdbql` | Query layer for TezzDB | Add parameterized query examples and tests. |
| `actor` | Local actors, mailboxes, supervision, node metadata, and OTP-like app helpers | Local in-process spawn/send/receive, mailbox matching, restart supervision, hot version tags, and fail-closed remote node sends are native-smoke gated; add real scheduler, network distribution, and hot module replacement before promotion. |
| `llm_core` | f64 CPU transformer primitives plus signed int8-weight matmul | Add f32/f16/bf16/uint8 and lower-bit lanes, tensor descriptors, model-load fixtures, GPU/NPU backend gates, and performance data before claiming production LLM support. |
| `gui`, `gui_win` | Host GUI APIs | Add Windows-only examples and platform notes. |
| `tzgui`, `tzui`, `tnui`, `tezzui`, `wm` | UI stacks | Clarify supported host path and maturity. |
| `mmap`, `sys`, `task`, `event`, `frame` | Systems/runtime helpers | Add platform matrix and failure behavior. |

## Experimental Modules

| Module | Purpose | Required Before Promotion |
| --- | --- | --- |
| `gpu` | GPU runtime hooks | Backend availability matrix and fallback tests. |
| `npu` | NPU/model runtime hooks | Backend availability matrix and explicit unsupported behavior. |
| `tensor` | Tensor math helpers | Numeric correctness tests and memory ownership docs. |
| `nn`, `llm`, `tokenizer` | AI/LLM experiments | Stable model format, tests, and performance notes; build on the gated `llm_core` primitive lane instead of untested backend assumptions. |
| `tts`, `stt` | Speech experiments | Platform audio/runtime notes and examples. |
| `kernel`, `os` | Freestanding/kernel work | Separate build docs and target matrix. |
| `arduino`, `raspi` | Embedded board helpers | Board-specific build and flashing docs. |
| `cyber`, `intrin`, `simd` | Specialized acceleration/security helpers | Capability checks and fallback behavior. |

## Internal Or Tooling Modules

| Module | Purpose |
| --- | --- |
| `tnx` | Package/metadata style helpers. |
| `tezzinstall`, `tezzsetup` | Installer and setup flows. |
| `tnauto`, `tsm` | Automation and service management helpers. |
| `data`, `color`, `tzimage` | Supporting utility modules that need examples before stable promotion. |

## Promotion Rules

A module can move toward Stable Candidate only when:

- public functions have signatures and examples.
- ownership and error behavior are documented.
- platform support is explicit.
- smoke tests exist.
- experimental backend dependencies are isolated or clearly optional.

## Immediate Improvements

1. Keep adding deeper edge smoke tests as APIs graduate; the current stable
   candidate slice has native `io`/`str`/`math`/`time`/`vec`/`arena` coverage,
   including chunked stream IO and focused math/string/vector/arena edge gates.
2. Document fallback behavior for `gpu`, `npu`, `tls`, and GUI modules.
3. Reduce default prelude risk by separating stable and experimental imports.
4. Keep the curated `examples/dx` programs aligned with stable-candidate module
   behavior and the developer-experience gate.
5. Keep this inventory synchronized with `tezz.mod` and `lib/`.
6. Grow `llm_core` from f64 correctness primitives into dtype, model IO, and
   backend-specific LLM gates before any production LLM claim.
7. Grow `actor` from local deterministic actors into scheduler-backed actors,
   remote distribution, and benchmarked service-runtime gates before any
   Erlang/OTP-scale claim.

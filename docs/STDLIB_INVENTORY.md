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
| `std` | Common prelude and helpers | Keep imports predictable; consider separating experimental imports later. |
| `io` | Files, paths, streams, basic OS IO | Raw file read/write, File wrapper open/write/flush/seek/tell/close, failed-open/null guards, and portable path helpers are native-smoke gated; add directory listing and full wrapped-read backend tests next. |
| `str` | String helpers | Native search/prefix/suffix plus trim/case/slice/replace/repeat/pad/parse smoke is gated; add broader edge-case tests. |
| `math` | Numeric helpers | Native integer, float, divmod, aggregate, and dot-product smoke is gated; add trigonometry/log/edge-case tests. |
| `time` | Time and sleep helpers | Import smoke plus native clock/sleep/UTC-date smoke are gated on Windows/Linux x64; local timezone formatting still needs target-specific backend work before promotion. |
| `vec` | Dynamic vector utilities | Native integer vector push/get/set/pop/free smoke is gated; add generic insert/remove/find tests. |
| `arena` | Arena allocation helpers | Native allocation/alignment/strdup/mark/release/reset smoke is gated; add wrapped-buffer tests. |

## Beta Modules

| Module | Purpose | Next Hardening Step |
| --- | --- | --- |
| `net` | TCP, UDP, HTTP helpers | Add loopback socket and HTTP client/server tests. |
| `tls` | TLS runtime wrappers | Document backend policy and certificate behavior. |
| `tezzserve` | HTTP/server helpers | Add route, JSON, static file, and websocket smoke tests. |
| `tezzapi` | REST API framework | Add request/response validation examples. |
| `tezzdb` | Embedded database | Add transaction, index, WAL, and recovery tests. |
| `tezzdbql` | Query layer for TezzDB | Add parameterized query examples and tests. |
| `gui`, `gui_win` | Host GUI APIs | Add Windows-only examples and platform notes. |
| `tzgui`, `tzui`, `tnui`, `tezzui`, `wm` | UI stacks | Clarify supported host path and maturity. |
| `mmap`, `sys`, `task`, `event`, `frame` | Systems/runtime helpers | Add platform matrix and failure behavior. |

## Experimental Modules

| Module | Purpose | Required Before Promotion |
| --- | --- | --- |
| `gpu` | GPU runtime hooks | Backend availability matrix and fallback tests. |
| `npu` | NPU/model runtime hooks | Backend availability matrix and explicit unsupported behavior. |
| `tensor` | Tensor math helpers | Numeric correctness tests and memory ownership docs. |
| `nn`, `llm`, `tokenizer` | AI/LLM experiments | Stable model format, tests, and performance notes. |
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

1. Add deeper module smoke tests for `io`, `str`, `math`, `time`, `vec`, and
   `arena`; first native `io`/`str`/`math`/`time`/`vec`/`arena` coverage is now
   gated.
2. Document fallback behavior for `gpu`, `npu`, `tls`, and GUI modules.
3. Reduce default prelude risk by separating stable and experimental imports.
4. Add examples for the stable candidate modules.
5. Keep this inventory synchronized with `tezz.mod` and `lib/`.

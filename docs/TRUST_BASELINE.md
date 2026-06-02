# TezzNative Public Trust Baseline

This document defines how TezzNative describes itself publicly. The goal is to
make the project useful without overstating readiness.

## Current Position

TezzNative is a Python-readable native programming language for early
production hardening work. It is strongest today for:

- CLI tools and automation scripts.
- Native utilities and small services.
- C interop experiments and hot-path replacement work.
- Windows/Linux x64 native backend validation.
- Standard-library hardening around IO, strings, math, time, vectors, arenas,
  and local networking helpers.

It should not claim to replace Python, C, Go, Rust, or Node.js across every
domain yet. The public message is:

> Use TezzNative where Python feels slow and C feels painful.

## Verified Claims

| Claim | Evidence |
| --- | --- |
| Stable-core syntax and common type errors are gated. | `docs/CONFORMANCE.md` and `tests/conformance/run.*` |
| Windows/Linux x64 native smoke and reproducible output are gated for the current backend surface. | `docs/NATIVE_BACKEND.md`, `tests/conformance/run-native-smoke.*`, and `tests/conformance/run-native-reliability.*` |
| Starter C ABI layout and extern signatures are checked. | `docs/C_ABI.md` and `tests/conformance/run-abi.*` |
| Public benchmark fixtures are source-visible and repeatable. | `docs/BENCHMARKS.md` and `benchmarks/` |
| Release downloads have SHA-256 metadata and a manifest. | `docs/RELEASE_ENGINEERING.md` and `download/release_manifest.json` |
| Stable, beta, experimental, and internal surfaces are labeled. | `docs/STABILITY.md`, `docs/PLATFORM_SUPPORT.md`, and `docs/STDLIB_INVENTORY.md` |

## Claim Boundaries

TezzNative should not publicly claim:

- General-purpose replacement readiness for every Python or C use case.
- Production maturity for GPU, NPU, LLM, kernel, OS, embedded board, or GUI
  surfaces.
- Public-network HTTP, TLS, DNS-backed socket, or database production readiness
  beyond the documented beta surface.
- Performance superiority without generated benchmark CSV and metadata.
- ABI compatibility outside documented and tested starter layouts.

## Publication Rules

Public pages, README text, releases, and install/download pages should follow
these rules:

1. Use `Stable`, `Beta`, `Experimental`, or `Internal` labels for public
   surfaces.
2. Link claims to a doc, test runner, manifest, or benchmark fixture.
3. Mention platform scope when behavior is Windows/Linux x64 only.
4. Keep bytecode, native build, native run, and external language comparisons
   separate.
5. Treat missing optional toolchains and unsupported backends as skipped or
   unsupported, not as passing production evidence.
6. Update `docs/OPTIMIZATION_PLAN.md` when a milestone status changes.

## Baseline Status

Milestone 0 is complete for the current public surface when these entry points
exist and agree:

- `README.md`
- `docs/STABILITY.md`
- `docs/PLATFORM_SUPPORT.md`
- `docs/STDLIB_INVENTORY.md`
- `docs/CONFORMANCE.md`
- `docs/C_ABI.md`
- `docs/BENCHMARKS.md`
- `docs/RELEASE_ENGINEERING.md`
- `docs/TRUST_BASELINE.md`
- `docs/OPTIMIZATION_PLAN.md`

Future work can broaden claims only after adding tests or release artifacts
that prove the broader behavior.

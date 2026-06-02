# TezzNative Stable Standard Library Core

This document defines the current stable-candidate standard library contract.
The goal is a small, practical core for CLI tools, automation scripts, native
utilities, small services, and C interop support.

The stable-candidate modules are:

| Module | Role | Current Gate |
| --- | --- | --- |
| `std` | Common prelude helpers | Import smoke in stable conformance. |
| `io` | Files, directories, paths, streams, process helpers | Windows/Linux x64 native smoke for raw, wrapped, line, stream, path, directory, glob, and process helpers. |
| `str` | String search, slicing, trim/case, replace, repeat, parse, padding | Windows/Linux x64 native smoke plus empty-replace edge coverage. |
| `math` | Integer, float, aggregate, interpolation, trigonometric helpers | Windows/Linux x64 native smoke plus `divmod`, `smoothstep`, and `atan2` edge coverage. |
| `time` | Clock, sleep, UTC/local date formatting | Windows/Linux x64 native smoke for clock, sleep, UTC date, and local date shape. |
| `vec` | Type-erased dynamic vectors and typed convenience wrappers | Windows/Linux x64 native smoke plus reserve/fill/null-guard edge coverage. |
| `arena` | Bump allocation, mark/release, wrapped buffers | Windows/Linux x64 native smoke plus alignment, release, and wrapped-buffer edge coverage. |

## Ownership Rules

- Functions returning `str` usually allocate a new heap string unless the
  module documentation says otherwise. Callers own the result and should free
  non-null values.
- `io.File`, `vec.Vec`, and `arena.Arena` handles are explicit resources.
  Callers should close or free them when finished.
- `arena_from_buf` wraps caller-owned memory. `arena_free` releases only the
  arena handle for wrapped buffers, not the external buffer.
- `vec` stores byte copies of elements. String-vector helpers store string
  pointers; `svec_free_all` frees stored strings and the vector.

## Failure Rules

- Null inputs are accepted only where the function documents a null-safe
  behavior.
- Allocating functions return null on allocation failure.
- Mutating resource functions return `0` on success and `-1` for invalid
  handles, invalid arguments, or failed allocation.
- `math.divmod` returns `-1` when the divisor is zero or output pointers are
  null.
- `arena_alloc_aligned` returns null when the requested alignment is not a
  positive power of two.
- `arena_release` accepts only marks from the current arena history; future
  positions fail instead of moving the bump pointer beyond initialized state.

## Platform Notes

The current stable-candidate stdlib gate is verified on Windows x64 and Linux
x64 native executables. Runtime-backed helpers must stay explicit about whether
they use direct native lowering, host C runtime calls, process-backed fallback,
or unsupported stubs on a given platform.

Networking, TLS, GUI, database, GPU/NPU, AI, kernel, and embedded modules are
outside this stable-candidate contract unless their own docs say otherwise.

## Verification Commands

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-native-smoke.ps1
```

Linux or WSL:

```bash
bash tests/conformance/run-native-smoke.sh ./TezzNative-language/bin/tezzc-linux-x64
```

The stdlib edge fixtures are:

- `tests/conformance/native/stdlib_math_edges.tn`
- `tests/conformance/native/stdlib_collections_edges.tn`


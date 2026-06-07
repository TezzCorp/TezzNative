# TezzNative C ABI

TezzNative C interop is beta, but the starter ABI surface is now gated by
machine-readable layout checks on Windows and Linux x64.

## Current Contract

- `int` lowers to signed 64-bit integer (`int64_t` in generated C headers).
- Fixed-width signed integers lower exactly: `i8` -> `int8_t`, `i16` ->
  `int16_t`, `i32` -> `int32_t`, `i64` -> `int64_t`.
- Fixed-width unsigned integers lower exactly: `u8` -> `uint8_t`, `u16` ->
  `uint16_t`, `u32` -> `uint32_t`, `u64` -> `uint64_t`.
- `float` lowers to 64-bit floating point (`double`).
- `char` lowers to unsigned 8-bit integer (`uint8_t`).
- `str` lowers to `uint8_t *`.
- Pointers are pointer-sized and aligned to 8 bytes on the current x64 release
  targets.
- Fixed arrays are inline storage in structs and keep the element alignment.
- Struct fields are laid out in declaration order with C-style alignment and
  tail padding to the maximum field alignment.
- Function pointers are represented as native C function pointers when used
  through pointer types.

Packed or custom-aligned structs are not part of the stable contract yet. Use
the generated header and ABI manifest as the source of truth for every exported
layout.

## Tooling

Generate a C header:

```bash
tezzc cheader tests/conformance/abi/starter_abi.tn build/starter_abi.h
```

Generate a structured ABI manifest:

```bash
tezzc abidump tests/conformance/abi/starter_abi.tn build/starter_abi.tnx
```

Verify a program against a saved manifest:

```bash
tezzc abiverify tests/conformance/abi/starter_abi.tn build/starter_abi.tnx
```

The manifest uses schema `tezznative.abi.v1` and records:

- struct size and alignment
- every field name, offset, size, alignment, and type shape
- global value type shapes
- function names, extern flags, return type shapes, and parameter type shapes

## Calling C From TezzNative

Declare C functions with `extern fn` and `@abi("c")`:

```tn
@abi("c")
extern fn strlen(s:*char) -> int

fn main() -> int:
  ret strlen("hello")
```

The current ABI tests cover pointer parameters, by-value struct parameters,
fixed arrays inside structs, nested structs, scalar mixes, all fixed-width
integer C mappings, and `void` returns.

## Being Called From C

For TezzNative functions that should be called from C, generate a header with
`cheader` and include it from the C side. The header emits `_Static_assert`
checks for exported struct size and alignment so a C compiler catches layout
drift early.

Example TezzNative API:

```tn
struct AbiPair:
  left:int
  right:int

fn pair_add(p:AbiPair) -> int:
  ret p.left + p.right
```

Generated C callers should use the emitted `AbiPair` definition from
`tezzc cheader` instead of duplicating the layout manually.

## Release Gate

Before a C ABI surface is treated as release-ready:

- `tests/conformance/run-abi.ps1` must pass on Windows.
- `tests/conformance/run-abi.sh` must pass on Linux.
- GitHub Actions must run both lanes with full `abiverify`.
- The public SDK archive must include the matching compiler, tests, docs, and
  source used to generate the ABI manifest.

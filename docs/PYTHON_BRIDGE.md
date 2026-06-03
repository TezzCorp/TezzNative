# Python Bridge

Milestone 6 provides the first gated Python bridge surface:

```bash
tezzc pyext module.tn [out_dir] [--module name]
```

The command generates a CPython extension scaffold for ABI-safe TezzNative
functions. It is meant for the adoption path:

> Keep Python for orchestration, use TezzNative for native hot paths.

## Generated Files

`tezzc pyext tests/conformance/python_bridge/hot_math.tn build/pyext --module tn_hot_math`
generates:

- `tn_hot_math_pyext.c`: CPython wrapper source.
- `tn_hot_math.h`: C ABI declarations for wrapped functions.
- `setup.py`: setuptools extension scaffold.
- `README.md`: ownership and build notes for the generated module.
- `pyext_manifest.tnx`: deterministic wrapped/skipped function summary.

## Type Mapping

| TezzNative | Python Input | Python Return |
| --- | --- | --- |
| `int` / `i64` | `int` | `int` |
| `u8` | `int` in `0..255` | `int` |
| `float` / `f64` | `float` | `float` |
| `*char` / `*u8` parameter | contiguous buffer object | not returned |
| `void` return | n/a | `None` |

Structs, pointer returns, function pointers, and unsafe functions are skipped
in this starter bridge. The manifest records the skip reason instead of hiding
the function.

## Ownership Rules

- Primitive values are copied between Python and TezzNative.
- Buffer parameters are borrowed with `PyObject_GetBuffer` for the duration of
  the call and always released on success or error.
- Returned primitive values are converted to Python objects.
- The starter bridge does not transfer ownership of returned pointers.

## Build Shape

The generated `setup.py` accepts native implementation objects or libraries:

```bash
TEZZ_NATIVE_OBJECTS=/path/to/module.o python -m pip install .
```

`TEZZ_NATIVE_LIBRARIES` can also provide an OS-path-separated list of libraries.
The shared-library/object build path is intentionally separate from wrapper
generation so the ABI gate can remain deterministic on Windows and Linux.

## Gate

The Python bridge conformance runners validate command generation, wrapper
contents, buffer release behavior, header declarations, setup metadata,
ownership docs, and the manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-python-bridge.ps1 -Tezzc .\TezzNative-language\build\tezzc.exe
```

```bash
bash tests/conformance/run-python-bridge.sh ./TezzNative-language/bin/tezzc-linux-x64
```

Expected summary:

```text
PYBRIDGE_SUMMARY passed=8 failed=0
```

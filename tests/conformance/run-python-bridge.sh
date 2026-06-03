#!/usr/bin/env bash
set -euo pipefail

repo_root="${2:-}"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
else
  repo_root="$(cd "$repo_root" && pwd)"
fi
tezzc="${1:-}"

python3 - "$repo_root" "$tezzc" <<'PY'
import os
import shutil
import subprocess
import sys
import sysconfig

repo = os.path.abspath(sys.argv[1])
tezzc = sys.argv[2]
passed = 0
failed = 0

def pass_(name):
    global passed
    passed += 1
    print(f"PASS python-bridge/{name}")

def fail(name, message):
    global failed
    failed += 1
    print(f"FAIL python-bridge/{name} :: {message}")

def check(name, fn):
    try:
        fn()
        pass_(name)
    except Exception as exc:
        fail(name, str(exc))

def required(rel):
    path = os.path.join(repo, rel)
    if not os.path.exists(path):
        raise AssertionError(f"missing {rel}")
    return path

def read(path):
    with open(path, "r", encoding="ascii") as f:
        return f.read()

fixture = required(os.path.join("tests", "conformance", "python_bridge", "hot_math.tn"))
out_dir = os.path.join(repo, "build", "python_bridge_gate")
manifest_path = os.path.join(out_dir, "pyext_manifest.tnx")
wrapper_path = os.path.join(out_dir, "tn_hot_math_pyext.c")
header_path = os.path.join(out_dir, "tn_hot_math.h")
setup_path = os.path.join(out_dir, "setup.py")
readme_path = os.path.join(out_dir, "README.md")

def command_surface():
    if not tezzc:
        raise AssertionError("missing Tezzc")
    shutil.rmtree(out_dir, ignore_errors=True)
    subprocess.run([tezzc, "pyext", fixture, out_dir, "--module", "tn_hot_math"], check=True)

def generated_files():
    for path in [manifest_path, wrapper_path, header_path, setup_path, readme_path]:
        if not os.path.exists(path):
            raise AssertionError(f"missing generated file {path}")

def manifest():
    body = read(manifest_path)
    for needle in [
        "schema=tezznative.pyext.v1",
        "module=tn_hot_math",
        "wrapped=3",
        "skipped=2",
        "fn.add_i64=wrapped ret=i64 params=i64,i64",
        "fn.scale_f64=wrapped ret=f64 params=f64,f64",
        "fn.first_byte=wrapped ret=i64 params=*u8-buffer,i64",
        "fn.pair_sum=skipped reason=unsupported parameter 1 type unsupported",
        "fn.main=skipped reason=entrypoint main is not wrapped",
    ]:
        if needle not in body:
            raise AssertionError(f"manifest missing {needle}")

def wrapper_primitives():
    body = read(wrapper_path)
    for needle in [
        "PyLong_AsLongLong",
        "PyFloat_AsDouble",
        "PyLong_FromLongLong",
        "PyFloat_FromDouble",
        "PyInit_tn_hot_math",
        "{\"add_i64\", py_add_i64",
        "{\"scale_f64\", py_scale_f64",
    ]:
        if needle not in body:
            raise AssertionError(f"wrapper missing {needle}")

def wrapper_buffer_safety():
    body = read(wrapper_path)
    for needle in [
        "PyObject_GetBuffer(arg0, &buf0, PyBUF_CONTIG_RO)",
        "uint8_t* v0 = (uint8_t*)buf0.buf",
        "if(buf0_ready) PyBuffer_Release(&buf0)",
        "{\"first_byte\", py_first_byte",
    ]:
        if needle not in body:
            raise AssertionError(f"buffer wrapper missing {needle}")

def header_contract():
    body = read(header_path)
    for needle in [
        "extern int64_t add_i64(int64_t a, int64_t b);",
        "extern double scale_f64(double x, double factor);",
        "extern int64_t first_byte(uint8_t * buf, int64_t n);",
    ]:
        if needle not in body:
            raise AssertionError(f"header missing {needle}")

def setup_contract():
    body = read(setup_path)
    for needle in ["TEZZ_NATIVE_OBJECTS", "TEZZ_NATIVE_LIBRARIES", "Extension('tn_hot_math'", "tn_hot_math_pyext.c"]:
        if needle not in body:
            raise AssertionError(f"setup.py missing {needle}")

def ownership_docs():
    body = read(readme_path)
    for needle in ["Ownership Rules", "borrowed contiguous Python buffer views", "Returned `i64`", "Pointer returns and structs are intentionally not wrapped"]:
        if needle not in body:
            raise AssertionError(f"README missing {needle}")

for name, fn in [
    ("command-surface", command_surface),
    ("generated-files", generated_files),
    ("manifest", manifest),
    ("wrapper-primitives", wrapper_primitives),
    ("wrapper-buffer-safety", wrapper_buffer_safety),
    ("header-contract", header_contract),
    ("setup-contract", setup_contract),
    ("ownership-docs", ownership_docs),
]:
    check(name, fn)

cc = shutil.which("gcc") or shutil.which("clang") or shutil.which("cc")
include = sysconfig.get_paths().get("include", "")
if cc and include and os.path.exists(os.path.join(include, "Python.h")):
    try:
        obj = os.path.join(out_dir, "tn_hot_math_pyext.o")
        subprocess.run([cc, f"-I{include}", f"-I{out_dir}", "-std=c11", "-c", wrapper_path, "-o", obj], check=True)
        if os.path.exists(obj):
            print("PYBRIDGE_OPTIONAL_C_COMPILE_OK")
        else:
            print("PYBRIDGE_OPTIONAL_C_COMPILE_SKIP")
    except Exception:
        print("PYBRIDGE_OPTIONAL_C_COMPILE_SKIP")
else:
    print("PYBRIDGE_OPTIONAL_C_COMPILE_SKIP")

print(f"PYBRIDGE_SUMMARY passed={passed} failed={failed}")
sys.exit(1 if failed else 0)
PY

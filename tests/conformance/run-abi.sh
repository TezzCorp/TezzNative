#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEZZC="${1:-}"
VERIFY_MODE="${2:-verify}"
if [[ -z "$TEZZC" ]]; then
  if [[ -x "$ROOT/TezzNative-language/bin/tezzc-linux-x64" ]]; then
    TEZZC="$ROOT/TezzNative-language/bin/tezzc-linux-x64"
  elif command -v tezzc >/dev/null 2>&1; then
    TEZZC="$(command -v tezzc)"
  else
    TEZZC="tezzc"
  fi
fi

PYTHON_BIN=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

ABI_DIR="$ROOT/tests/conformance/abi"
ARTIFACT_DIR="$(mktemp -d)"
mkdir -p "$ROOT/build"
failed=0

cleanup() {
  rm -rf "$ARTIFACT_DIR"
}
trap cleanup EXIT

assert_contains() {
  local text="$1"
  local needle="$2"
  local label="$3"
  if [[ "$text" == *"$needle"* ]]; then
    return 0
  fi
  echo "FAIL $label missing snippet"
  echo "  expected snippet: $needle"
  return 1
}

for file in "$ABI_DIR"/*.tn; do
  name="$(basename "$file")"
  base="${name%.tn}"
  header="$ARTIFACT_DIR/$base.h"
  dump="$ARTIFACT_DIR/$base.tnx"

  output="$("$TEZZC" check "$file" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL abi/$name check exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi

  output="$("$TEZZC" cheader "$file" "$header" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 || ! -f "$header" ]]; then
    echo "FAIL abi/$name cheader exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi

  output="$("$TEZZC" abidump "$file" "$dump" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 || ! -f "$dump" ]]; then
    echo "FAIL abi/$name abidump exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi

  if [[ "$VERIFY_MODE" != "--skip-verify" && "$VERIFY_MODE" != "skip" ]]; then
    output="$("$TEZZC" abiverify "$file" "$dump" 2>&1)"
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL abi/$name abiverify exit=$rc"
      printf '  %s\n' "$output"
      failed=$((failed + 1))
      continue
    fi
  fi

  header_text="$(cat "$header")"
  ok=1

  for snippet in \
    'typedef struct AbiPair {' \
    'int64_t left;' \
    'int64_t right;' \
    '_Static_assert(sizeof(AbiPair) == 16, "ABI size mismatch for AbiPair");' \
    '_Static_assert(_Alignof(AbiPair) == 8, "ABI align mismatch for AbiPair");' \
    'typedef struct AbiBuffer {' \
    'uint8_t * data;' \
    'int64_t len;' \
    '_Static_assert(sizeof(AbiBuffer) == 16, "ABI size mismatch for AbiBuffer");' \
    'typedef struct AbiPacket {' \
    'uint8_t bytes[8];' \
    '_Static_assert(sizeof(AbiPacket) == 16, "ABI size mismatch for AbiPacket");' \
    'typedef struct AbiNumbers {' \
    'uint8_t flag;' \
    'int64_t count;' \
    'double ratio;' \
    '_Static_assert(sizeof(AbiNumbers) == 24, "ABI size mismatch for AbiNumbers");' \
    '_Static_assert(_Alignof(AbiNumbers) == 8, "ABI align mismatch for AbiNumbers");' \
    'typedef struct AbiTable {' \
    'int64_t values[3];' \
    'AbiPair head;' \
    '_Static_assert(sizeof(AbiTable) == 40, "ABI size mismatch for AbiTable");' \
    '_Static_assert(_Alignof(AbiTable) == 8, "ABI align mismatch for AbiTable");'; do
    assert_contains "$header_text" "$snippet" "abi/$name cheader" || ok=0
  done

  if [[ -z "$PYTHON_BIN" ]]; then
    echo "FAIL abi/$name abidump JSON check needs python3 or python"
    ok=0
  elif ! "$PYTHON_BIN" - "$dump" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    abi = json.load(f)

def fail(msg):
    print(f"FAIL abi/starter_abi.tn {msg}")
    raise SystemExit(1)

def shape(ty):
    if not isinstance(ty, dict):
        return "<missing>"
    kind = ty.get("kind")
    if kind == "ptr":
        return f"ptr({shape(ty.get('elem'))})"
    if kind == "array":
        return f"array({shape(ty.get('elem'))},{ty.get('len')})"
    if kind == "struct":
        return f"struct:{ty.get('name')}"
    return str(kind)

def expect(actual, expected, label):
    if actual != expected:
        fail(f"{label} expected={expected!r} got={actual!r}")

expect(abi.get("schema"), "tezznative.abi.v1", "schema")
structs = {s.get("name"): s for s in abi.get("structs", [])}
fns = {fn.get("name"): fn for fn in abi.get("fns", [])}

def check_struct(name, size, align, fields):
    st = structs.get(name)
    if not st:
        fail(f"missing struct {name}")
    expect(st.get("size"), size, f"{name}.size")
    expect(st.get("align"), align, f"{name}.align")
    got_fields = {field.get("name"): field for field in st.get("fields", [])}
    for field_name, off, fsize, falign, fshape in fields:
        field = got_fields.get(field_name)
        if not field:
            fail(f"missing field {name}.{field_name}")
        expect(field.get("off"), off, f"{name}.{field_name}.off")
        expect(field.get("size"), fsize, f"{name}.{field_name}.size")
        expect(field.get("align"), falign, f"{name}.{field_name}.align")
        expect(shape(field.get("type")), fshape, f"{name}.{field_name}.type")

def check_fn(name, ret, params, extern=True):
    fn = fns.get(name)
    if not fn:
        fail(f"missing function {name}")
    expect(fn.get("extern"), extern, f"{name}.extern")
    expect(shape(fn.get("ret")), ret, f"{name}.ret")
    expect([shape(p) for p in fn.get("params", [])], params, f"{name}.params")

check_struct("AbiPair", 16, 8, [
    ("left", 0, 8, 8, "i64"),
    ("right", 8, 8, 8, "i64"),
])
check_struct("AbiBuffer", 16, 8, [
    ("data", 0, 8, 8, "ptr(u8)"),
    ("len", 8, 8, 8, "i64"),
])
check_struct("AbiPacket", 16, 8, [
    ("tag", 0, 8, 8, "i64"),
    ("bytes", 8, 8, 1, "array(u8,8)"),
])
check_struct("AbiNumbers", 24, 8, [
    ("flag", 0, 1, 1, "u8"),
    ("count", 8, 8, 8, "i64"),
    ("ratio", 16, 8, 8, "f64"),
])
check_struct("AbiTable", 40, 8, [
    ("values", 0, 24, 8, "array(i64,3)"),
    ("head", 24, 16, 8, "struct:AbiPair"),
])

check_fn("abi_pair_sum", "i64", ["ptr(struct:AbiPair)", "i64"])
check_fn("abi_buffer_len", "i64", ["struct:AbiBuffer"])
check_fn("abi_packet_send", "void", ["ptr(struct:AbiPacket)"])
check_fn("abi_numbers_scale", "i64", ["struct:AbiNumbers", "ptr(struct:AbiNumbers)"])
check_fn("abi_table_first", "i64", ["ptr(struct:AbiTable)"])
PY
  then
    ok=0
  fi

  if [[ "$ok" -ne 1 ]]; then
    failed=$((failed + 1))
    continue
  fi

  echo "ABI_OK $name"
done

echo "ABI_SUMMARY failed=$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

exit 0

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

ABI_DIR="$ROOT/tests/conformance/abi"
ARTIFACT_DIR="$(mktemp -d)"
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
  dump_text="$(cat "$dump")"
  ok=1

  for snippet in \
    'typedef struct AbiPair {' \
    'int64_t left;' \
    'int64_t right;' \
    '_Static_assert(sizeof(AbiPair) == 16, "ABI size mismatch for AbiPair");' \
    'typedef struct AbiBuffer {' \
    'uint8_t * data;' \
    'typedef struct AbiPacket {' \
    'uint8_t bytes[8];'; do
    assert_contains "$header_text" "$snippet" "abi/$name cheader" || ok=0
  done

  for snippet in \
    '"name":"AbiPair","size":16,"align":8' \
    '"name":"AbiBuffer","size":16,"align":8' \
    '"name":"AbiPacket","size":16,"align":8' \
    '"name":"abi_pair_sum","extern":true,"ret":"i64"' \
    '"name":"abi_buffer_len","extern":true,"ret":"i64"' \
    '"name":"abi_packet_send","extern":true,"ret":"void"'; do
    assert_contains "$dump_text" "$snippet" "abi/$name abidump" || ok=0
  done

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

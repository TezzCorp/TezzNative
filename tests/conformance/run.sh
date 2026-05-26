#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEZZC="${1:-}"
if [[ -z "$TEZZC" ]]; then
  if [[ -x "$ROOT/TezzNative-language/bin/tezzc-linux-x64" ]]; then
    TEZZC="$ROOT/TezzNative-language/bin/tezzc-linux-x64"
  elif command -v tezzc >/dev/null 2>&1; then
    TEZZC="$(command -v tezzc)"
  else
    TEZZC="tezzc"
  fi
fi

VALID_DIR="$ROOT/tests/conformance/valid"
INVALID_DIR="$ROOT/tests/conformance/invalid"
DIAG_DIR="$ROOT/tests/conformance/diagnostics"
STDLIB_DIR="$ROOT/tests/conformance/stdlib"
failed=0

run_check() {
  local path="$1"
  local output
  output="$("$TEZZC" check "$path" 2>&1)"
  local rc=$?
  printf '%s\n' "$output"
  return "$rc"
}

for file in "$VALID_DIR"/*.tn; do
  output="$(run_check "$file")"
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "OK valid/$(basename "$file")"
  else
    echo "FAIL valid/$(basename "$file") exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
  fi
done

if [[ -d "$STDLIB_DIR" ]]; then
  for file in "$STDLIB_DIR"/*.tn; do
    [[ -e "$file" ]] || continue
    output="$(run_check "$file")"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      echo "OK stdlib/$(basename "$file")"
    else
      echo "FAIL stdlib/$(basename "$file") exit=$rc"
      printf '  %s\n' "$output"
      failed=$((failed + 1))
    fi
  done
fi

for file in "$INVALID_DIR"/*.tn; do
  output="$(run_check "$file")"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    diag="$DIAG_DIR/$(basename "${file%.tn}").diag.txt"
    if [[ -f "$diag" ]]; then
      expected="$(tr -d '\r' < "$diag")"
      if [[ "$output" != *"$expected"* ]]; then
        echo "FAIL invalid/$(basename "$file") diagnostic mismatch"
        echo "  expected snippet: $expected"
        printf '  %s\n' "$output"
        failed=$((failed + 1))
      else
        echo "INVALID_OK $(basename "$file") diagnostic=matched"
      fi
    else
      echo "INVALID_OK $(basename "$file")"
    fi
  else
    echo "FAIL invalid/$(basename "$file") unexpectedly passed"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
  fi
done

echo "CONFORMANCE_SUMMARY failed=$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

exit 0

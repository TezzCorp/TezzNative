#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEZZC="${1:-}"
if [[ -n "$TEZZC" && "$TEZZC" == */* && -e "$TEZZC" ]]; then
  TEZZC="$(cd "$(dirname "$TEZZC")" && pwd)/$(basename "$TEZZC")"
fi
if [[ -z "$TEZZC" ]]; then
  if [[ -x "$ROOT/TezzNative-language/bin/tezzc-linux-x64" ]]; then
    TEZZC="$ROOT/TezzNative-language/bin/tezzc-linux-x64"
  elif command -v tezzc >/dev/null 2>&1; then
    TEZZC="$(command -v tezzc)"
  else
    TEZZC="tezzc"
  fi
fi

FAILED=0
PASSED=0

run_check() {
  local path="$1"
  local output
  output="$("$TEZZC" check "$path" 2>&1)"
  local rc=$?
  printf '%s\n' "$output"
  return "$rc"
}

trim_trailing_newlines() {
  local value="$1"
  while [[ "$value" == *$'\n' ]]; do
    value="${value%$'\n'}"
  done
  printf '%s' "$value"
}

run_valid_suite() {
  local suite="$1"
  local rel_dir="$2"
  local dir="$ROOT/tests/conformance/$rel_dir"
  [[ -d "$dir" ]] || return

  for file in "$dir"/*.tn; do
    [[ -e "$file" ]] || continue
    local name display output rc
    name="$(basename "$file")"
    if [[ "$rel_dir" == "$suite" || "$rel_dir" == "$suite/"* ]]; then
      display="$rel_dir/$name"
    else
      display="$suite/$rel_dir/$name"
    fi
    output="$(run_check "$file")"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      echo "OK $display"
      PASSED=$((PASSED + 1))
    else
      echo "FAIL $display exit=$rc"
      printf '  %s\n' "$output"
      FAILED=$((FAILED + 1))
    fi
  done
}

run_invalid_suite() {
  local suite="$1"
  local rel_dir="$2"
  local rel_diag="$3"
  local dir="$ROOT/tests/conformance/$rel_dir"
  local diag_dir="$ROOT/tests/conformance/$rel_diag"
  [[ -d "$dir" ]] || return

  for file in "$dir"/*.tn; do
    [[ -e "$file" ]] || continue
    local name base display output rc diag expected
    name="$(basename "$file")"
    base="${name%.tn}"
    if [[ "$rel_dir" == "$suite" || "$rel_dir" == "$suite/"* ]]; then
      display="$rel_dir/$name"
    else
      display="$suite/$rel_dir/$name"
    fi
    output="$(run_check "$file")"
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
      diag="$diag_dir/$base.diag.txt"
      if [[ -f "$diag" ]]; then
        expected="$(trim_trailing_newlines "$(tr -d '\r' < "$diag")")"
        if [[ "$output" != *"$expected"* ]]; then
          echo "FAIL $display diagnostic mismatch"
          echo "  expected snippet: $expected"
          printf '  %s\n' "$output"
          FAILED=$((FAILED + 1))
        else
          echo "INVALID_OK $display diagnostic=matched"
          PASSED=$((PASSED + 1))
        fi
      else
        echo "INVALID_OK $display"
        PASSED=$((PASSED + 1))
      fi
    else
      echo "FAIL $display unexpectedly passed"
      printf '  %s\n' "$output"
      FAILED=$((FAILED + 1))
    fi
  done
}

run_valid_suite "stable-core" "valid"
run_valid_suite "parser" "parser/valid"
run_valid_suite "typecheck" "typecheck/valid"
run_valid_suite "stdlib" "stdlib"

run_invalid_suite "diagnostics" "invalid" "diagnostics"
run_invalid_suite "parser" "parser/invalid" "diagnostics/parser"
run_invalid_suite "typecheck" "typecheck/invalid" "diagnostics/typecheck"

echo "CONFORMANCE_SUMMARY passed=$PASSED failed=$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

exit 0

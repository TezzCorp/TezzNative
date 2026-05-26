#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEZZC="${1:-}"
MODE="${2:-check}"
if [[ -z "$TEZZC" ]]; then
  if [[ -x "$ROOT/TezzNative-language/bin/tezzc-linux-x64" ]]; then
    TEZZC="$ROOT/TezzNative-language/bin/tezzc-linux-x64"
  elif command -v tezzc >/dev/null 2>&1; then
    TEZZC="$(command -v tezzc)"
  else
    TEZZC="tezzc"
  fi
fi

failed=0
for file in "$ROOT/benchmarks/tezz"/*.tn; do
  name="$(basename "$file")"
  output="$("$TEZZC" check "$file" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL benchmark/$name check exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi
  echo "BENCH_CHECK_OK $name"

  if [[ "$MODE" == "--check-only" || "$MODE" == "check" ]]; then
    continue
  fi

  output="$("$TEZZC" run "$file" --bc 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL benchmark/$name bytecode exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
  else
    echo "BENCH_BYTECODE_OK $name"
  fi
done

echo "BENCH_SUMMARY failed=$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

exit 0

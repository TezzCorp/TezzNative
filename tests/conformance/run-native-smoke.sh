#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEZZC="${1:-}"
MODE="${2:-run}"
TARGET="${TN_NATIVE_TARGET:-}"
if [[ -z "$TEZZC" ]]; then
  if [[ -x "$ROOT/TezzNative-language/bin/tezzc-linux-x64" ]]; then
    TEZZC="$ROOT/TezzNative-language/bin/tezzc-linux-x64"
  elif command -v tezzc >/dev/null 2>&1; then
    TEZZC="$(command -v tezzc)"
  else
    TEZZC="tezzc"
  fi
fi

if [[ -z "$TARGET" ]]; then
  case "$(uname -s)" in
    Linux*) TARGET="linux" ;;
  esac
fi

SMOKE_DIR="$ROOT/tests/conformance/native"
ARTIFACT_DIR="$(mktemp -d)"
failed=0

cleanup() {
  rm -rf "$ARTIFACT_DIR"
}
trap cleanup EXIT

normalize_output() {
  tr -d '\r' | sed -e '${/^$/d;}'
}

for file in "$SMOKE_DIR"/*.tn; do
  name="$(basename "$file")"
  base="${name%.tn}"

  output="$("$TEZZC" check "$file" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL native/$name check exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi

  if [[ "$MODE" == "--check-only" || "$MODE" == "check" ]]; then
    echo "NATIVE_CHECK_OK $name"
    continue
  fi

  if [[ "$MODE" == "--check-ir-only" || "$MODE" == "ir" ]]; then
    output="$("$TEZZC" ir "$file" --repro 2>&1)"
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL native/$name ir exit=$rc"
      printf '  %s\n' "$output"
      failed=$((failed + 1))
    else
      echo "NATIVE_IR_OK $name"
    fi
    continue
  fi

  exe="$ARTIFACT_DIR/$base"
  build_args=(buildexe "$file" "$exe" --verify)
  if [[ -n "$TARGET" ]]; then
    build_args+=(--target "$TARGET")
  fi

  output="$("$TEZZC" "${build_args[@]}" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 || ! -x "$exe" ]]; then
    echo "FAIL native/$name build exit=$rc"
    printf '  %s\n' "$output"
    failed=$((failed + 1))
    continue
  fi

  if [[ "$MODE" == "--build-only" || "$MODE" == "build" ]]; then
    echo "NATIVE_BUILD_OK $name"
    continue
  fi

  run_output="$(cd "$ARTIFACT_DIR" && "$exe" 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL native/$name run exit=$rc"
    printf '  %s\n' "$run_output"
    failed=$((failed + 1))
    continue
  fi

  stdout_file="$SMOKE_DIR/$base.stdout.txt"
  if [[ -f "$stdout_file" ]]; then
    expected="$(normalize_output < "$stdout_file")"
    actual="$(printf '%s' "$run_output" | normalize_output)"
    if [[ "$actual" != "$expected" ]]; then
      echo "FAIL native/$name stdout mismatch"
      echo "  expected: $expected"
      echo "  actual:   $actual"
      failed=$((failed + 1))
      continue
    fi
  fi

  echo "NATIVE_OK $name"
done

echo "NATIVE_SMOKE_SUMMARY failed=$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

exit 0

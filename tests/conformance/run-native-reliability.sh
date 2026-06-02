#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEZZC="${1:-}"
TARGET="${TN_NATIVE_TARGET:-}"
ITERATIONS="${TN_NATIVE_REPRO_ITERATIONS:-2}"

if [[ "$ITERATIONS" -lt 2 ]]; then
  echo "Iterations must be at least 2" >&2
  exit 1
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

if [[ -z "$TARGET" ]]; then
  case "$(uname -s)" in
    Linux*) TARGET="linux" ;;
    *) TARGET="x86_64" ;;
  esac
fi

NATIVE_DIR="$ROOT/tests/conformance/native"
ARTIFACT_DIR="$(mktemp -d)"
failed=0
fixtures=(
  hello.tn
  loop_math.tn
  many_args.tn
  many_args_nested.tn
  many_args_strings.tn
  math_module.tn
  string_ops.tn
  string_transforms.tn
  struct_array.tn
  collections_memory.tn
)

cleanup() {
  rm -rf "$ARTIFACT_DIR"
}
trap cleanup EXIT

normalize_output() {
  tr -d '\r' | sed -e '${/^$/d;}'
}

can_run_target() {
  case "$(uname -s):$1" in
    Linux*:linux|Linux*:elf) return 0 ;;
    MINGW*:x86_64|MINGW*:x64|MINGW*:amd64|MINGW*:native|MINGW*:x86) return 0 ;;
    MSYS*:x86_64|MSYS*:x64|MSYS*:amd64|MSYS*:native|MSYS*:x86) return 0 ;;
    CYGWIN*:x86_64|CYGWIN*:x64|CYGWIN*:amd64|CYGWIN*:native|CYGWIN*:x86) return 0 ;;
  esac
  return 1
}

output="$("$TEZZC" buildexe --status 2>&1)"
rc=$?
if [[ "$rc" -ne 0 || "$output" != *Windows* || "$output" != *Linux* ]]; then
  echo "FAIL native-reliability buildexe-status exit=$rc"
  printf '  %s\n' "$output"
  failed=$((failed + 1))
else
  echo "NATIVE_RELIABILITY_STATUS_OK"
fi

for fixture in "${fixtures[@]}"; do
  source="$NATIVE_DIR/$fixture"
  base="${fixture%.tn}"
  if [[ ! -f "$source" ]]; then
    echo "FAIL native-reliability/$fixture missing"
    failed=$((failed + 1))
    continue
  fi

  hashes=()
  first_exe=""
  for ((i=1; i<=ITERATIONS; i++)); do
    exe="$ARTIFACT_DIR/${base}-${i}"
    output="$("$TEZZC" buildexe "$source" "$exe" --target "$TARGET" --verify 2>&1)"
    rc=$?
    if [[ "$rc" -ne 0 || ! -f "$exe" ]]; then
      echo "FAIL native-reliability/$fixture build iteration=$i exit=$rc"
      printf '  %s\n' "$output"
      failed=$((failed + 1))
      continue
    fi

    if [[ -z "$first_exe" ]]; then
      first_exe="$exe"
    fi
    hashes+=("$(sha256sum "$exe" | awk '{print toupper($1)}')")
  done

  if [[ "${#hashes[@]}" -ne "$ITERATIONS" ]]; then
    continue
  fi

  unique="$(printf '%s\n' "${hashes[@]}" | sort -u)"
  unique_count="$(printf '%s\n' "$unique" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$unique_count" -ne 1 ]]; then
    echo "FAIL native-reliability/$fixture reproducible hashes=$(printf '%s,' "${hashes[@]}")"
    failed=$((failed + 1))
    continue
  fi

  if can_run_target "$TARGET"; then
    chmod +x "$first_exe"
    run_output="$(cd "$ARTIFACT_DIR" && "$first_exe" 2>&1)"
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL native-reliability/$fixture run exit=$rc"
      printf '  %s\n' "$run_output"
      failed=$((failed + 1))
      continue
    fi

    stdout_file="$NATIVE_DIR/${base}.stdout.txt"
    if [[ -f "$stdout_file" ]]; then
      expected="$(normalize_output < "$stdout_file")"
      actual="$(printf '%s' "$run_output" | normalize_output)"
      if [[ "$actual" != "$expected" ]]; then
        echo "FAIL native-reliability/$fixture stdout mismatch"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        failed=$((failed + 1))
        continue
      fi
    fi
  fi

  echo "NATIVE_REPRO_OK $fixture target=$TARGET sha256=$unique"
done

bad_out="$ARTIFACT_DIR/unsupported-target.bin"
output="$("$TEZZC" buildexe "$NATIVE_DIR/hello.tn" "$bad_out" --target tezznative-unsupported-target 2>&1)"
rc=$?
if [[ "$rc" -eq 0 || -f "$bad_out" || "$output" != *"unsupported target"* ]]; then
  echo "FAIL native-reliability unsupported-target exit=$rc"
  printf '  %s\n' "$output"
  failed=$((failed + 1))
else
  echo "NATIVE_UNSUPPORTED_TARGET_OK"
fi

echo "NATIVE_RELIABILITY_SUMMARY failed=$failed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

exit 0

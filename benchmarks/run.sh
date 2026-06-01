#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEZZC="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

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

cd "$ROOT"

CHECK_ONLY=0
INCLUDE_EXTERNAL=0
SKIP_NATIVE=0
REQUIRE_NATIVE=0
ITERATIONS=3
OUT_PATH="$ROOT/benchmarks/results/latest-linux.csv"
TIMEOUT_SECONDS=60
TARGET="${TN_NATIVE_TARGET:-}"
if [[ -z "$TARGET" ]]; then
  case "$(uname -s)" in
    Linux*) TARGET="linux" ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only|check)
      CHECK_ONLY=1
      ;;
    --include-external)
      INCLUDE_EXTERNAL=1
      ;;
    --skip-native)
      SKIP_NATIVE=1
      ;;
    --require-native)
      REQUIRE_NATIVE=1
      ;;
    --iterations)
      shift
      ITERATIONS="${1:-3}"
      ;;
    --out)
      shift
      OUT_PATH="${1:-$OUT_PATH}"
      ;;
    --timeout)
      shift
      TIMEOUT_SECONDS="${1:-60}"
      ;;
    *)
      echo "Unknown benchmark option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$(dirname "$OUT_PATH")"
RUN_ID="$(date +%s)-$$"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
FAILED=0

csv_escape() {
  local value="${1//$'\r'/}"
  value="${value//$'\n'/ | }"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

bench_category() {
  case "$1" in
    startup) echo "startup" ;;
    *file*|*io*) echo "file-io" ;;
    *string*|*scan*|*text*) echo "string-processing" ;;
    *sum*|*loop*|*numeric*|*math*) echo "numeric-loop" ;;
    *) echo "general" ;;
  esac
}

hash_text_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print toupper($1)}'
  else
    shasum -a 256 "$file" | awk '{print toupper($1)}'
  fi
}

append_result() {
  local bench="$1"
  local language="$2"
  local mode="$3"
  local phase="$4"
  local iteration="$5"
  local elapsed_ms="$6"
  local peak_bytes="$7"
  local bytes="$8"
  local exit_code="$9"
  local timed_out="${10}"
  local command_text="${11}"
  local output_hash="${12}"
  local preview="${13}"
  {
    csv_escape "tezznative.benchmark-result.v1"; printf ','
    csv_escape "$RUN_ID"; printf ','
    csv_escape "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; printf ','
    csv_escape "$(uname -srmo 2>/dev/null || uname -a)"; printf ','
    csv_escape "$(uname -m)"; printf ','
    csv_escape "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"; printf ','
    csv_escape "$bench"; printf ','
    csv_escape "$(bench_category "$bench")"; printf ','
    csv_escape "$language"; printf ','
    csv_escape "$mode"; printf ','
    csv_escape "$phase"; printf ','
    csv_escape "$iteration"; printf ','
    csv_escape "$elapsed_ms"; printf ','
    csv_escape "$peak_bytes"; printf ','
    csv_escape "$bytes"; printf ','
    csv_escape "$exit_code"; printf ','
    csv_escape "$timed_out"; printf ','
    csv_escape "$command_text"; printf ','
    csv_escape "$output_hash"; printf ','
    csv_escape "$preview"; printf '\n'
  } >> "$OUT_PATH"
}

measure_run() {
  local bench="$1"
  local language="$2"
  local mode="$3"
  local phase="$4"
  local iteration="$5"
  local bytes="$6"
  shift 6
  local out_file="$WORK_DIR/stdout.txt"
  local err_file="$WORK_DIR/stderr.txt"
  local time_file="$WORK_DIR/time.txt"
  rm -f "$out_file" "$err_file" "$time_file"
  local start_ns end_ns elapsed_ms rc timed_out peak_kb peak_bytes command_text output_hash preview
  command_text="$*"
  start_ns="$(date +%s%N)"
  timed_out=0
  if command -v timeout >/dev/null 2>&1; then
    if command -v /usr/bin/time >/dev/null 2>&1; then
      timeout "$TIMEOUT_SECONDS" /usr/bin/time -f 'peak_kb=%M' -o "$time_file" "$@" >"$out_file" 2>"$err_file"
      rc=$?
    else
      timeout "$TIMEOUT_SECONDS" "$@" >"$out_file" 2>"$err_file"
      rc=$?
    fi
    if [[ "$rc" -eq 124 ]]; then
      timed_out=1
    fi
  else
    if command -v /usr/bin/time >/dev/null 2>&1; then
      /usr/bin/time -f 'peak_kb=%M' -o "$time_file" "$@" >"$out_file" 2>"$err_file"
      rc=$?
    else
      "$@" >"$out_file" 2>"$err_file"
      rc=$?
    fi
  fi
  end_ns="$(date +%s%N)"
  elapsed_ms="$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e - s) / 1000000 }')"
  peak_kb="$(sed -n 's/^peak_kb=//p' "$time_file" 2>/dev/null | tail -n 1)"
  if [[ -z "$peak_kb" ]]; then
    peak_bytes=0
  else
    peak_bytes=$((peak_kb * 1024))
  fi
  cat "$out_file" "$err_file" > "$WORK_DIR/output.txt"
  output_hash="$(hash_text_file "$WORK_DIR/output.txt")"
  preview="$(tr '\r\n' '  ' < "$WORK_DIR/output.txt" | cut -c 1-240)"
  append_result "$bench" "$language" "$mode" "$phase" "$iteration" "$elapsed_ms" "$peak_bytes" "$bytes" "$rc" "$timed_out" "$command_text" "$output_hash" "$preview"
  return "$rc"
}

printf '"schema","run_id","timestamp_utc","os","arch","processor_count","bench","category","language","mode","phase","iteration","elapsed_ms","peak_working_set_bytes","bytes","exit_code","timed_out","command","output_sha256","output_preview"\n' > "$OUT_PATH"

for file in benchmarks/tezz/*.tn; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  bench="${name%.tn}"
  if ! measure_run "$bench" "tezznative" "check" "check" 0 0 "$TEZZC" check "$file"; then
    echo "FAIL benchmark/$name check"
    FAILED=$((FAILED + 1))
    continue
  fi
  echo "BENCH_CHECK_OK $name"

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    continue
  fi

  i=1
  while [[ "$i" -le "$ITERATIONS" ]]; do
    if ! measure_run "$bench" "tezznative" "bytecode" "run" "$i" 0 "$TEZZC" run "$file" --bc; then
      echo "FAIL benchmark/$name bytecode"
      FAILED=$((FAILED + 1))
      break
    fi
    i=$((i + 1))
  done

  if [[ "$SKIP_NATIVE" -eq 0 ]]; then
    exe="$WORK_DIR/$bench"
    build_args=(buildexe "$file" "$exe" --verify)
    if [[ -n "$TARGET" ]]; then
      build_args+=(--target "$TARGET")
    fi
    if measure_run "$bench" "tezznative" "native" "build" 0 0 "$TEZZC" "${build_args[@]}" && [[ -x "$exe" ]]; then
      bytes="$(wc -c < "$exe" | tr -d ' ')"
      i=1
      while [[ "$i" -le "$ITERATIONS" ]]; do
        if ! measure_run "$bench" "tezznative" "native" "run" "$i" "$bytes" "$exe"; then
          echo "FAIL benchmark/$name native"
          FAILED=$((FAILED + 1))
          break
        fi
        i=$((i + 1))
      done
    else
      echo "WARN benchmark/$name native build unavailable"
      if [[ "$REQUIRE_NATIVE" -eq 1 ]]; then
        FAILED=$((FAILED + 1))
      fi
    fi
  fi
done

run_interpreted_dir() {
  local language="$1"
  local mode="$2"
  local dir="$3"
  local pattern="$4"
  local tool="$5"
  if [[ -z "$tool" || ! -d "$dir" ]]; then
    echo "SKIP $language benchmarks: tool or directory not available"
    return
  fi
  for file in "$dir"/$pattern; do
    [[ -f "$file" ]] || continue
    bench="$(basename "$file")"
    bench="${bench%.*}"
    i=1
    while [[ "$i" -le "$ITERATIONS" ]]; do
      if ! measure_run "$bench" "$language" "$mode" "run" "$i" 0 "$tool" "$file"; then
        echo "FAIL benchmark/$(basename "$file") $language"
        FAILED=$((FAILED + 1))
        break
      fi
      i=$((i + 1))
    done
  done
}

run_compiled_dir() {
  local language="$1"
  local dir="$2"
  local pattern="$3"
  local tool="$4"
  if [[ -z "$tool" || ! -d "$dir" ]]; then
    echo "SKIP $language benchmarks: tool or directory not available"
    return
  fi
  for file in "$dir"/$pattern; do
    [[ -f "$file" ]] || continue
    bench="$(basename "$file")"
    bench="${bench%.*}"
    exe="$WORK_DIR/$bench-$language"
    build_args=()
    case "$language" in
      c) build_args=(-O3 -std=c11 "$file" -o "$exe") ;;
      go) build_args=(build -o "$exe" "$file") ;;
      rust) build_args=(-C opt-level=3 "$file" -o "$exe") ;;
      *) echo "Unsupported compiled language: $language"; continue ;;
    esac
    if ! measure_run "$bench" "$language" "native" "build" 0 0 "$tool" "${build_args[@]}"; then
      echo "FAIL benchmark/$(basename "$file") $language build"
      FAILED=$((FAILED + 1))
      continue
    fi
    bytes="$(wc -c < "$exe" 2>/dev/null | tr -d ' ')"
    if [[ -z "$bytes" ]]; then
      bytes=0
    fi
    i=1
    while [[ "$i" -le "$ITERATIONS" ]]; do
      if ! measure_run "$bench" "$language" "native" "run" "$i" "$bytes" "$exe"; then
        echo "FAIL benchmark/$(basename "$file") $language native"
        FAILED=$((FAILED + 1))
        break
      fi
      i=$((i + 1))
    done
  done
}

if [[ "$INCLUDE_EXTERNAL" -eq 1 && "$CHECK_ONLY" -eq 0 ]]; then
  PYTHON_TOOL="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
  NODE_TOOL="$(command -v node 2>/dev/null || true)"
  CC_TOOL="$(command -v gcc 2>/dev/null || command -v clang 2>/dev/null || command -v cc 2>/dev/null || true)"
  GO_TOOL="$(command -v go 2>/dev/null || true)"
  RUST_TOOL="$(command -v rustc 2>/dev/null || true)"
  run_interpreted_dir "python" "interpreter" "$ROOT/benchmarks/python" "*.py" "$PYTHON_TOOL"
  run_interpreted_dir "nodejs" "interpreter" "$ROOT/benchmarks/node" "*.js" "$NODE_TOOL"
  run_compiled_dir "c" "$ROOT/benchmarks/c" "*.c" "$CC_TOOL"
  run_compiled_dir "go" "$ROOT/benchmarks/go" "*.go" "$GO_TOOL"
  run_compiled_dir "rust" "$ROOT/benchmarks/rust" "*.rs" "$RUST_TOOL"
fi

METADATA_PATH="${OUT_PATH%.csv}.metadata.json"
cat > "$METADATA_PATH" <<JSON
{
  "schema": "tezznative.benchmark-run.v1",
  "run_id": "$RUN_ID",
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tezzc": "$TEZZC",
  "iterations": $ITERATIONS,
  "check_only": $CHECK_ONLY,
  "include_external": $INCLUDE_EXTERNAL,
  "skip_native": $SKIP_NATIVE,
  "require_native": $REQUIRE_NATIVE,
  "timeout_seconds": $TIMEOUT_SECONDS,
  "host": {
    "os": "$(uname -srmo 2>/dev/null || uname -a)",
    "arch": "$(uname -m)",
    "processor_count": "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
  },
  "result_csv": "$OUT_PATH"
}
JSON

echo "BENCH_RESULTS $OUT_PATH"
echo "BENCH_METADATA $METADATA_PATH"
echo "BENCH_SUMMARY failed=$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

exit 0

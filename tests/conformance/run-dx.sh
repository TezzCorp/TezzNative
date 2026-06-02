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

dx_pass() {
  echo "DX_OK $1"
  PASSED=$((PASSED + 1))
}

dx_fail() {
  local name="$1"
  local reason="$2"
  local output="${3:-}"
  echo "DX_FAIL ${name} ${reason}"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" | sed 's/^/  /'
  fi
  FAILED=$((FAILED + 1))
}

run_tezz() {
  "$TEZZC" "$@" 2>&1
}

require_contains() {
  local name="$1"
  local text="$2"
  shift 2
  local needle
  for needle in "$@"; do
    if [[ "$text" != *"$needle"* ]]; then
      dx_fail "$name" "missing '${needle}'" "$text"
      return 1
    fi
  done
  return 0
}

run_lint_case() {
  local name="$1"
  local path="$2"
  shift 2
  local output rc
  output="$(run_tezz lint "$path")"
  rc=$?
  if [[ "$rc" -gt 1 ]]; then
    dx_fail "$name" "exit=${rc}" "$output"
    return
  fi
  if require_contains "$name" "$output" "$@"; then
    dx_pass "$name"
  fi
}

cd "$ROOT" || exit 1

diagnostic_unknown="$(run_tezz check tests/conformance/dx/diagnostics/actionable_unknown_name.tn)"
rc=$?
if [[ "$rc" -eq 0 ]]; then
  dx_fail "diagnostic-help-unknown-name" "unexpected pass" "$diagnostic_unknown"
elif require_contains "diagnostic-help-unknown-name" "$diagnostic_unknown" \
  "unknown name 'missing_total'" \
  "ret missing_total" \
  "^" \
  "help: declare the name before use"; then
  dx_pass "diagnostic-help-unknown-name"
fi

diagnostic_arity="$(run_tezz check tests/conformance/dx/diagnostics/wrong_arity_help.tn)"
rc=$?
if [[ "$rc" -eq 0 ]]; then
  dx_fail "diagnostic-help-wrong-arity" "unexpected pass" "$diagnostic_arity"
elif require_contains "diagnostic-help-wrong-arity" "$diagnostic_arity" \
  "wrong number of arguments in call to 'join_pair' (expected 2, got 1)" \
  "ret join_pair(\"left\")" \
  "^" \
  "help: check the function signature"; then
  dx_pass "diagnostic-help-wrong-arity"
fi

tmp_root="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

cp tests/conformance/dx/fmt/control_flow.input.tn "$tmp_root/control_flow.tn"
fmt_output="$(run_tezz fmt "$tmp_root/control_flow.tn")"
rc=$?
if [[ "$rc" -ne 0 ]]; then
  dx_fail "fmt-control-flow" "exit=${rc}" "$fmt_output"
elif ! cmp -s "$tmp_root/control_flow.tn" tests/conformance/dx/fmt/control_flow.formatted.tn; then
  dx_fail "fmt-control-flow" "formatted output mismatch" "$(cat "$tmp_root/control_flow.tn")"
else
  dx_pass "fmt-control-flow"
fi

fmt_again="$(run_tezz fmt "$tmp_root/control_flow.tn")"
rc=$?
if [[ "$rc" -ne 0 ]]; then
  dx_fail "fmt-idempotent" "exit=${rc}" "$fmt_again"
elif ! cmp -s "$tmp_root/control_flow.tn" tests/conformance/dx/fmt/control_flow.formatted.tn; then
  dx_fail "fmt-idempotent" "second format changed output" "$(cat "$tmp_root/control_flow.tn")"
else
  dx_pass "fmt-idempotent"
fi

native_out="$tmp_root/dx_native_build"
build_output="$(run_tezz buildexe examples/dx/native_build.tn "$native_out" --target linux --verify)"
rc=$?
if [[ "$rc" -ne 0 || ! -f "$native_out" ]]; then
  dx_fail "build-native-example" "exit=${rc}" "$build_output"
else
  chmod +x "$native_out"
  run_output="$("$native_out" 2>&1)"
  run_rc=$?
  if [[ "$run_rc" -ne 0 || "$run_output" != *"dx-native-build"* ]]; then
    dx_fail "build-native-example" "run-exit=${run_rc}" "$run_output"
  else
    dx_pass "build-native-example"
  fi
fi

run_lint_case "lint-unused-var" \
  tests/conformance/dx/lint/unused_var.tn \
  "lint[unused-var]" \
  "unused variable 'unused_value'"

run_lint_case "lint-shadowed-var" \
  tests/conformance/dx/lint/shadowed_var.tn \
  "lint[shadowed-var]" \
  "shadowing 'value'"

run_lint_case "lint-suppress" \
  tests/conformance/dx/lint/suppress_unused_var.tn \
  "OK:"

while IFS= read -r -d '' example; do
  name="example-check-$(basename "$example" .tn)"
  output="$(run_tezz check "$example")"
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    dx_pass "$name"
  else
    dx_fail "$name" "exit=${rc}" "$output"
  fi
done < <(find examples/dx -maxdepth 1 -type f -name '*.tn' -print0 | sort -z)

hello_output="$(run_tezz run examples/dx/hello.tn --bc)"
rc=$?
if [[ "$rc" -eq 0 && "$hello_output" == *"hello from TezzNative"* ]]; then
  dx_pass "run-hello-example"
else
  dx_fail "run-hello-example" "exit=${rc}" "$hello_output"
fi

lsp_output="$(run_tezz check tools/tezz_lsp.tn)"
rc=$?
if [[ "$rc" -eq 0 ]]; then
  dx_pass "lsp-source-check"
else
  dx_fail "lsp-source-check" "exit=${rc}" "$lsp_output"
fi

if [[ ! -f tezznative-vscode/snippets/snippets.json ]]; then
  dx_fail "vscode-snippets-supported" "snippets file missing"
else
  snippet_text="$(cat tezznative-vscode/snippets/snippets.json)"
  missing=""
  for required in "Function Definition" "Main Function" "Import Module" "Extern Function" "File Read Write"; do
    if [[ "$snippet_text" != *"\"${required}\""* ]]; then
      missing="${missing}${required},"
    fi
  done
  forbidden=""
  for bad in "tts." "stt." "tezzserve.serve_ws_upgrade" "tezzdbql.db_query"; do
    if [[ "$snippet_text" == *"$bad"* ]]; then
      forbidden="${forbidden}${bad},"
    fi
  done
  if [[ -z "$missing" && -z "$forbidden" ]]; then
    dx_pass "vscode-snippets-supported"
  else
    dx_fail "vscode-snippets-supported" "missing=${missing} forbidden=${forbidden}"
  fi
fi

echo "DX_SUMMARY passed=${PASSED} failed=${FAILED}"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
exit 0

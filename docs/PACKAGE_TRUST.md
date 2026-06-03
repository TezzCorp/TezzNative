# TezzNative Package Trust

Milestone 5 makes the package surface reproducible enough for early projects to
share source, rebuild dependency state, and audit what the SDK will install.

## Status

Package trust is completed for the current first-party SDK package set.

The gate covers:

- public `tezz` launcher scripts for Windows and POSIX.
- `tools/tezz.tn` command source.
- `tezz.mod`, `tezz.lock`, and `registry.tnx`.
- semantic versions in package metadata.
- deterministic lock and registry ordering.
- package checksums against local `lib/*.tn` sources.
- lock/registry URL and checksum parity.
- generated package inventory documentation.

## Commands

| Command | Status | Contract |
| --- | --- | --- |
| `tezz init` | Gated | Creates `tezz.mod`, `.tezz/cache`, and a template project using SemVer dependency pins. |
| `tezz add <name@version>` | Gated | Installs a package through the registry or explicit URL, verifies the 8-hex package checksum, updates `tezz.mod`, and updates `tezz.lock`. |
| `tezz remove <name>` | Gated | Removes the dependency from `tezz.mod`, rewrites `tezz.lock` with fresh metadata, and deletes the local `lib/<name>.tn` copy when present. |
| `tezz update` | Gated | Keeps the SDK updater path explicit: `--check`, `--install`, `--reinstall`, and `--uninstall`. Package version updates should be expressed through `tezz add <name@version>` followed by `tezz lock`. |
| `tezz lock` | Gated | Rebuilds `tezz.lock` from `tezz.mod` and local package sources in deterministic sorted order. |
| `tezz publish [out_path]` | Gated | Regenerates `tezz.lock`, writes registry metadata, and reports `publish: registry metadata ready`. Uploading the registry is a release-site operation, not an implicit network side effect. |
| `tezz test` | Gated | Keeps existing conformance, stdlib, tooling, runtime, and native lanes available from the tool. |
| `tezz build --release` | Gated | Builds with release defaults and refreshes the dependency lock when `tezz.mod` exists. |

## Metadata Rules

`tezz.mod` is the source declaration:

- `name` must be a lowercase package identifier.
- `version` must use `x.y.z` semantic version form.
- `module_root` is `lib` for the public SDK.
- `registry` points to `https://tn.tezzcorp.com/registry.tnx`.
- `registry_lib` points to `https://tn.tezzcorp.com/download/sdk/lib/`.
- `dep.*` and `optdep.*` versions use the same `x.y.z` form.

`tezz.lock` is the reproducibility declaration:

```text
# lock-meta v1 lines=<count> payload=<hash8> key=<key-id|none> sig=<sig|none>
name@version CHECKSUM URL
```

`registry.tnx` is the install declaration:

```text
# registry-meta v1 lines=<count> payload=<hash8> key=<key-id|none> sig=<sig|none>
name@version URL CHECKSUM
```

The package checksum is TezzNative's current deterministic 8-hex source-byte
hash used by `tools/tezz.tn` for package files, with `CRLF` normalized to
`LF` so Windows/Linux checkouts verify the same package payload. Release
archives and installers use SHA-256 through `download/release_manifest.json`;
both layers are gated, but they serve different scopes.

## Generated Docs

The package-trust gate generates `build/package_docs.generated.md` from
`tezz.mod` and `tezz.lock`. This proves the package inventory can be recreated
from source metadata instead of being hand-maintained.

The generated file is a build artifact and is intentionally not committed.

## First-Party Package Targets

These are the first-party package areas that should graduate behind the same
trust gate. A target is not promoted by name alone; it needs examples, tests,
metadata, and documented failure behavior.

| Target | Current Source | Promotion Rule |
| --- | --- | --- |
| JSON | `net` helpers and future `json` package | Parser/serializer fixtures, invalid-input tests, and docs generated from source metadata. |
| CLI argument parser | `examples/dx/cli_flags.tn` and future `cli` package | Flag parsing examples, error messages, and native/bytecode smoke. |
| Logging | future `log` package | Level filtering, formatting, file/stdout sinks, and failure behavior. |
| Config file support | future `config` package | Key/value, environment override, missing-file behavior, and example app. |
| Regex | future `regex` package | Deterministic matcher tests, unsupported-feature errors, and benchmark fixture. |
| SQLite binding | `tezzdb`/future `sqlite` binding | Open/query/transaction tests and C ABI layout checks where native SQLite is used. |
| HTTP client/server polish | `net`, `tezzserve`, `tezzapi` | Local loopback tests, parser edge cases, timeouts, and public-network tests only when isolated from CI flakiness. |
| Testing assertions | future `test` package | Assertion helpers, diff output, exit-code contract, and examples. |
| Benchmark helpers | `benchmarks/` harness and future `bench` package | Stable CSV/JSON output, skipped-tool reporting, and reproducible workload sources. |

## Verification

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-package-trust.ps1 -Tezzc .\TezzNative-language\build\tezzc.exe
```

Linux or WSL:

```bash
bash tests/conformance/run-package-trust.sh ./TezzNative-language/bin/tezzc-linux-x64
```

Expected:

```text
PACKAGE_TRUST_SUMMARY passed=12 failed=0
```

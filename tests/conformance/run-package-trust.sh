#!/usr/bin/env bash
set -euo pipefail

repo_root="${2:-}"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
else
  repo_root="$(cd "$repo_root" && pwd)"
fi
tezzc="${1:-}"

python3 - "$repo_root" "$tezzc" <<'PY'
import os
import re
import subprocess
import sys

repo = os.path.abspath(sys.argv[1])
tezzc = sys.argv[2]
passed = 0
failed = 0

def pass_(name):
    global passed
    passed += 1
    print(f"PASS package-trust/{name}")

def fail(name, message):
    global failed
    failed += 1
    print(f"FAIL package-trust/{name} :: {message}")

def check(name, fn):
    try:
        fn()
        pass_(name)
    except Exception as exc:
        fail(name, str(exc))

def required(rel):
    path = os.path.join(repo, rel)
    if not os.path.exists(path):
        raise AssertionError(f"missing {rel}")
    return path

def read_text(rel):
    with open(os.path.join(repo, rel), "r", encoding="ascii") as f:
        return f.read()

def read_kv(rel):
    out = {}
    with open(os.path.join(repo, rel), "r", encoding="ascii") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = re.split(r"\s*=\s*", line, maxsplit=1)
            if len(parts) != 2:
                raise AssertionError(f"malformed key/value line in {rel}: {raw.rstrip()}")
            out[parts[0]] = parts[1]
    return out

semver_re = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)([-+][0-9A-Za-z.-]+)?$")
name_re = re.compile(r"^[a-z][a-z0-9_]*$")

def assert_semver(value, label):
    if not semver_re.match(value):
        raise AssertionError(f"{label} is not semantic version x.y.z: {value}")

def assert_name(value, label):
    if not name_re.match(value):
        raise AssertionError(f"{label} has invalid package name: {value}")

def hash8_bytes(data):
    h = 5381
    for b in data:
        h = (((h << 5) + h + b) & 0x7FFFFFFF)
    return f"{h:08X}"

def hash8_text(text):
    return hash8_bytes(text.encode("ascii"))

def hash8_source_file(path):
    with open(path, "rb") as f:
        return hash8_bytes(f.read().replace(b"\r\n", b"\n"))

def meta_line(rel, kind):
    path = os.path.join(repo, rel)
    with open(path, "r", encoding="ascii") as f:
        lines = [line.rstrip("\n").rstrip("\r") for line in f]
    if len(lines) < 2:
        raise AssertionError(f"{kind} file is empty")
    m = re.match(rf"^# {kind} v1 lines=([0-9]+) payload=([0-9A-F]{{8}}) key=([A-Za-z0-9]+|none) sig=([A-Za-z0-9]+|none)$", lines[0])
    if not m:
        raise AssertionError(f"bad {kind} metadata line: {lines[0]}")
    payload_lines = [line.strip() for line in lines if line.strip() and not line.strip().startswith("#")]
    payload = "".join(line + "\n" for line in payload_lines)
    if int(m.group(1)) != len(payload_lines):
        raise AssertionError(f"{kind} metadata line count mismatch")
    actual = hash8_text(payload)
    if actual != m.group(2):
        raise AssertionError(f"{kind} payload hash mismatch: expected {m.group(2)} got {actual}")

def lock_entries(rel):
    rows = []
    with open(os.path.join(repo, rel), "r", encoding="ascii") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 3:
                raise AssertionError(f"malformed lock entry: {line}")
            if "@" not in parts[0]:
                raise AssertionError(f"malformed lock package token: {parts[0]}")
            name, version = parts[0].split("@", 1)
            rows.append({"token": parts[0], "name": name, "version": version, "checksum": parts[1], "url": parts[2], "raw": line})
    return rows

def registry_entries(rel):
    rows = []
    with open(os.path.join(repo, rel), "r", encoding="ascii") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 3:
                raise AssertionError(f"malformed registry entry: {line}")
            if "@" not in parts[0]:
                raise AssertionError(f"malformed registry package token: {parts[0]}")
            name, version = parts[0].split("@", 1)
            rows.append({"token": parts[0], "name": name, "version": version, "url": parts[1], "checksum": parts[2], "raw": line})
    return rows

metadata = {}
deps = {}
locks = []
registry = []

def surface_files():
    for rel in ["tezz", "tezz.cmd", "tezz.ps1", "tezz.mod", "tezz.lock", "registry.tnx", "tools/tezz.tn", "docs/PACKAGE_TRUST.md"]:
        required(rel)

def tezz_mod_semver():
    global metadata, deps
    metadata = read_kv("tezz.mod")
    for key in ["name", "version", "module_root", "registry", "registry_lib"]:
        if key not in metadata:
            raise AssertionError(f"missing {key} in tezz.mod")
    assert_name(metadata["name"], "project name")
    assert_semver(metadata["version"], "project version")
    if metadata["module_root"] != "lib":
        raise AssertionError("module_root must be lib")
    if metadata["registry"] != "https://tn.tezzcorp.com/registry.tnx":
        raise AssertionError("unexpected registry URL")
    if metadata["registry_lib"] != "https://tn.tezzcorp.com/download/sdk/lib/":
        raise AssertionError("unexpected registry_lib URL")
    deps = {}
    for key, value in metadata.items():
        if key.startswith("dep."):
            name = key[4:]
            assert_name(name, "dependency")
            assert_semver(value, f"dependency {name}")
            deps[name] = value
        if key.startswith("optdep."):
            name = key[7:]
            assert_name(name, "optional dependency")
            assert_semver(value, f"optional dependency {name}")
    if len(deps) < 7:
        raise AssertionError("expected first-party dependency inventory")

def lock_format():
    global locks
    meta_line("tezz.lock", "lock-meta")
    locks = lock_entries("tezz.lock")
    seen = set()
    previous = ""
    for entry in locks:
        assert_name(entry["name"], "lock package")
        assert_semver(entry["version"], f"lock package {entry['name']}")
        if not re.match(r"^[0-9A-F]{8}$", entry["checksum"]):
            raise AssertionError(f"bad checksum for {entry['token']}")
        if not entry["url"].startswith(metadata["registry_lib"]):
            raise AssertionError(f"lock provenance URL mismatch for {entry['token']}")
        if entry["token"] in seen:
            raise AssertionError(f"duplicate lock token {entry['token']}")
        seen.add(entry["token"])
        if previous and previous > entry["raw"]:
            raise AssertionError("lock entries are not sorted")
        previous = entry["raw"]

def registry_format():
    global registry
    meta_line("registry.tnx", "registry-meta")
    registry = registry_entries("registry.tnx")
    seen = set()
    previous = ""
    for entry in registry:
        assert_name(entry["name"], "registry package")
        assert_semver(entry["version"], f"registry package {entry['name']}")
        if not re.match(r"^[0-9A-F]{8}$", entry["checksum"]):
            raise AssertionError(f"bad registry checksum for {entry['token']}")
        if not entry["url"].startswith(metadata["registry_lib"]):
            raise AssertionError(f"registry provenance URL mismatch for {entry['token']}")
        if entry["token"] in seen:
            raise AssertionError(f"duplicate registry token {entry['token']}")
        seen.add(entry["token"])
        if previous and previous > entry["raw"]:
            raise AssertionError("registry entries are not sorted")
        previous = entry["raw"]

def lock_registry_parity():
    by_token = {entry["token"]: entry for entry in registry}
    for entry in locks:
        if entry["token"] not in by_token:
            raise AssertionError(f"missing registry entry for {entry['token']}")
        reg = by_token[entry["token"]]
        if reg["url"] != entry["url"] or reg["checksum"] != entry["checksum"]:
            raise AssertionError(f"registry mismatch for {entry['token']}")
    for name, version in deps.items():
        token = f"{name}@{version}"
        if token not in by_token:
            raise AssertionError(f"missing registry entry for dependency {token}")

def local_checksums():
    for entry in locks:
        path = os.path.join(repo, "lib", entry["name"] + ".tn")
        if not os.path.exists(path):
            raise AssertionError(f"missing local package source lib/{entry['name']}.tn")
        actual = hash8_source_file(path)
        if actual != entry["checksum"]:
            raise AssertionError(f"checksum mismatch for {entry['name']}: expected {entry['checksum']} got {actual}")

def tool_command_surface():
    source = read_text("tools/tezz.tn")
    for needle in ["cmd_init", "cmd_add", "cmd_remove", "cmd_update", "cmd_lock", "cmd_publish", "cmd_test", "cmd_build_path"]:
        if f"fn {needle}" not in source:
            raise AssertionError(f"missing function {needle}")
    for cmd in ["init", "add", "remove", "update", "lock", "publish", "test", "build"]:
        if f'streq(cmd, "{cmd}")' not in source:
            raise AssertionError(f"missing dispatch for {cmd}")
    for literal in ["tezz add <name@ver>", "tezz remove <name>", "publish: registry metadata ready", "--release"]:
        if literal not in source:
            raise AssertionError(f"missing command help/literal: {literal}")

def launcher_contract():
    for rel in ["tezz", "tezz.ps1", "tezz.cmd"]:
        content = read_text(rel)
        if "tools/tezz.tn" not in content and "tools\\tezz.tn" not in content:
            raise AssertionError(f"{rel} missing tools/tezz.tn")
        if "--sdk-root" not in content:
            raise AssertionError(f"{rel} missing --sdk-root handoff")

def generated_package_docs():
    out = os.path.join(repo, "build", "package_docs.generated.md")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    lines = [
        "# Generated Package Inventory",
        "",
        "Source: tezz.mod + tezz.lock",
        "",
        "| Package | Version | Checksum | Source |",
        "| --- | --- | --- | --- |",
    ]
    for entry in sorted(locks, key=lambda item: item["name"]):
        lines.append(f"| `{entry['name']}` | `{entry['version']}` | `{entry['checksum']}` | {entry['url']} |")
    with open(out, "w", encoding="ascii") as f:
        f.write("\n".join(lines))
    generated = open(out, "r", encoding="ascii").read()
    for name in ["std", "io", "net", "math", "vec", "arena"]:
        if f"`{name}`" not in generated:
            raise AssertionError(f"generated package docs missing {name}")

def first_party_target_docs():
    doc = read_text("docs/PACKAGE_TRUST.md")
    for target in ["JSON", "CLI argument parser", "Logging", "Config file support", "Regex", "SQLite binding", "HTTP client/server", "Testing assertions", "Benchmark helpers"]:
        if target not in doc:
            raise AssertionError(f"docs missing first-party target: {target}")

def tool_source_check():
    if not tezzc:
        return
    tool = os.path.join(repo, "tools", "tezz.tn")
    subprocess.run([tezzc, "check", tool], check=True)

def tool_command_workflow():
    if not tezzc:
        return
    import shutil
    import tempfile
    compiler = os.path.abspath(tezzc)
    tool = os.path.join(repo, "tools", "tezz.tn")
    tmp = tempfile.mkdtemp(prefix="tezz-package-trust-")
    try:
        def run_tool(*args):
            subprocess.run([compiler, "run", "--bc", tool, "--", *args, "--tezzc", compiler, "--sdk-root", repo], cwd=tmp, check=True)
        run_tool("init", ".", "--name", "package_probe", "--template", "cli")
        os.makedirs(os.path.join(tmp, "lib"), exist_ok=True)
        for name in ["std", "time", "task", "io"]:
            shutil.copyfile(os.path.join(repo, "lib", name + ".tn"), os.path.join(tmp, "lib", name + ".tn"))
        run_tool("remove", "io")
        with open(os.path.join(tmp, "tezz.mod"), "r", encoding="ascii") as f:
            if "dep.io" in f.read():
                raise AssertionError("tezz remove left dep.io in tezz.mod")
        io_entries = [entry for entry in locks if entry["name"] == "io"]
        if not io_entries:
            raise AssertionError("root lock missing io entry")
        io_entry = io_entries[0]
        os.makedirs(os.path.join(tmp, ".tezz", "cache"), exist_ok=True)
        shutil.copyfile(os.path.join(repo, "lib", "io.tn"), os.path.join(tmp, ".tezz", "cache", "io-0.1.0.tn"))
        run_tool("add", "io@0.1.0", io_entry["url"], io_entry["checksum"])
        if not os.path.exists(os.path.join(tmp, "lib", "io.tn")):
            raise AssertionError("tezz add did not restore lib/io.tn")
        run_tool("publish", "build/registry_probe.tnx")
        out = os.path.join(tmp, "build", "registry_probe.tnx")
        if not os.path.exists(out):
            raise AssertionError("tezz publish did not write registry output")
        with open(out, "r", encoding="ascii") as f:
            published = f.read()
        for token in ["std@0.1.0", "io@0.1.0", "time@0.1.0", "task@0.1.0"]:
            if token not in published:
                raise AssertionError(f"published registry missing {token}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

checks = [
    ("surface-files", surface_files),
    ("tezz-mod-semver", tezz_mod_semver),
    ("lock-format-and-metadata", lock_format),
    ("registry-format-and-metadata", registry_format),
    ("lock-registry-parity", lock_registry_parity),
    ("local-checksums", local_checksums),
    ("tool-command-surface", tool_command_surface),
    ("launcher-contract", launcher_contract),
    ("generated-package-docs", generated_package_docs),
    ("first-party-target-docs", first_party_target_docs),
]
if tezzc:
    checks.append(("tool-source-check", tool_source_check))
    checks.append(("tool-command-workflow", tool_command_workflow))

for name, fn in checks:
    check(name, fn)

print(f"PACKAGE_TRUST_SUMMARY passed={passed} failed={failed}")
sys.exit(1 if failed else 0)
PY

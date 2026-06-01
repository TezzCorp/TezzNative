# Release Engineering

TezzNative release hardening is based on reproducible evidence, not broad
claims.

## Public Artifacts

Each public SDK release must publish:

- `download/tezznative-sdk.zip`
- `download/tezznative-sdk.zip.sha256`
- `download/tezznative-sdk-linux.tar.gz`
- `download/tezznative-sdk-linux.tar.gz.sha256`
- `download/tezzc-linux-x64.gz`
- `download/tezzc-linux-x64.gz.sha256`
- `download/release_manifest.json`
- `download/release_manifest.json.sha256`
- `registry.tnx`

The release manifest records artifact path, URL, byte length, and SHA-256 hash.

## Verification

Build a manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\release\build_release_manifest.ps1
```

Verify a manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\release\verify_release_manifest.ps1
```

CI also runs a fixture that verifies normal artifacts and proves tampered files
fail verification.

## Installer Rule

Installers must download the matching `.sha256` file, compare it to the
downloaded archive, and stop before extraction when the checksum does not
match.

## Release Checklist

- Rebuild Windows and Linux SDK archives.
- Build the Linux direct compiler with `TN_STATIC=1` so hosted runners do not
  depend on the WSL/build-host glibc version.
- Publish the gzip-compressed Linux direct compiler for hosted CI bootstrap.
- Generate archive `.sha256` files.
- Generate and verify `release_manifest.json`.
- Run stable conformance, native smoke, ABI, and release-security checks.
- Upload archives, checksums, manifest, registry, install scripts, and SDK
  mirror files to `tn.tezzcorp.com`.
- Verify public HTTPS downloads and API redirects against local hashes.
- Push GitHub changes and wait for Actions success.

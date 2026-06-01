# Security Policy

## Reporting Vulnerabilities

Report suspected vulnerabilities privately by email to `security@tezzcorp.com`.
Do not open a public issue for exploitable behavior, credential exposure,
installer compromise, or release artifact tampering.

Please include:

- Affected TezzNative version or SDK hash.
- Operating system and install method.
- Reproduction steps or a minimal proof of concept.
- Whether the issue affects compiler output, installer behavior, runtime
  modules, website APIs, or downloaded artifacts.

## Supported Surface

The supported public surface is the current release channel documented in
`version.json`, plus the download artifacts listed in the release manifest.
Experimental modules remain best-effort and may change quickly.

## Release Integrity

Public SDK archives are published with SHA-256 checksums and a release
manifest. Installers must fail closed when a downloaded archive does not match
its published checksum.

# Telemetry And Privacy

TezzNative compiler and runtime usage does not require telemetry.

The website may record best-effort operational events for downloads, update
checks, and installer status so broken releases can be detected quickly. These
events must not block local compiler use.

## Current Policy

- Compiler execution is local and does not send usage telemetry.
- Install scripts can report install/update/check status to the portal when the
  network is available.
- Portal event failures are ignored by the installer.
- IP addresses are stored as salted hashes by the website backend.
- Crash dumps and source files are not uploaded by the compiler/runtime.

## Privacy Rules

- Do not require accounts for SDK downloads.
- Do not collect source code, command arguments, or project paths in telemetry.
- Keep event fields minimal: platform, version, status, install/update mode,
  and user agent where the web server naturally receives it.
- Treat any future crash/error reporting as opt-in.

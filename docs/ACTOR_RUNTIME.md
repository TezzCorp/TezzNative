# TezzNative Actor Runtime

The `actor` module is the first TezzNative actor and OTP-like application
foundation. It is intentionally small and gated by native smoke tests.

## Current Capabilities

- Local actor systems with fixed actor, mailbox, and node capacities.
- `actor.spawn`, `actor.send`, `actor.send_text`, FIFO `actor.receive`, and
  selective `actor.receive_match`.
- Mailbox capacity checks and dropped-message accounting.
- Parent links, restart policies, `actor.supervise`, `actor.mark_failed`, and
  restart counters.
- `OtpApp` helpers for app start, worker spawn, worker stop, and app
  supervision.
- Node metadata plus `actor.node_send` for local-node routing. Remote nodes
  fail closed with `actor.remote_unsupported()`.
- Module version tags through `actor.set_module`, `actor.hot_reload`, and
  `actor.version_of`.

## Public Error Helpers

Use helper functions instead of importing numeric constants:

```tn
actor.ok()
actor.err()
actor.any()
actor.alive()
actor.stopped()
actor.restart_permanent()
actor.remote_unsupported()
```

## Not Production OTP Yet

This module does not yet provide:

- preemptive scheduler-backed actors.
- cross-process or cross-node distribution.
- authenticated remote messaging.
- live code replacement.
- complete supervisor child specs or restart intensity windows.
- service registry, tracing, metrics, or production crash reports.

Those items are tracked in `docs/OPTIMIZATION_PLAN.md` under Milestone 11.

## Verification

The native smoke fixture is:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\conformance\run-native-smoke.ps1
```

The focused actor fixture is:

```powershell
.\bin\tezzc.exe buildexe tests\conformance\native\actor_runtime.tn build\actor_runtime.exe --verify
.\build\actor_runtime.exe
```

Expected output:

```text
actor-runtime
```

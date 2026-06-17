# Changelog

See the [repository CHANGELOG](../../CHANGELOG.md) for full project notes. Package-specific versions match the repo.

## 1.0.0

First stable, semantically-versioned release published to [pub.dev](https://pub.dev/packages/hydra_client). MIT `LICENSE` and pub.dev metadata (`topics`, `homepage`, `documentation`, `issue_tracker`) added. API surface is unchanged from `0.2.0` — this is a stabilization + packaging milestone, not a breaking change; apps on `0.2.0` upgrade by bumping the constraint to `^1.0.0`.

Pre-release hardening: self-contained pub.dev README with quick-start and a **Security considerations** section, runnable `example/`, explicit `platforms:` declaration, dartdoc on public API entry points, native WebSocket transport now closes its `HttpClient` on socket teardown (no per-reconnect leak), and the message parser falls back to a raw message instead of throwing on a non-string `InvalidInput` payload.

## 0.2.0

Reconnecting WebSocket (`ReconnectingHydraSession`), seq dedupe / gap hint (`SeqTracker`), typed `TxValid` / `TxInvalid` / `Snapshot` events, `HydraHeadFacade`, `HydraStateStore`, and `HydraSigner` interface.

## 0.1.0

Initial `HydraSession`, HTTP client, and core parsers.

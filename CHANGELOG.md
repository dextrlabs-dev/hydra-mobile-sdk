# Changelog

## 0.2.0

- **WebSocket:** `ReconnectingHydraSession` with exponential backoff (capped, default 3s max) and a `messages` stream that survives reconnects; `HydraReconnectPolicy` and `HydraConnectionState`.
- **Sync:** `SeqTracker` + `HydraSyncPolicy` (dedupe replayed `seq`, optional `GET /snapshot/last-seen` hint on sequence gaps).
- **Inbound types:** `HydraTxValid`, `HydraTxInvalid`, `HydraServerSnapshot` for common timed server outputs (still falls back to `HydraTimedServerOutput` / `HydraRawMessage`).
- **Facade:** `HydraHeadFacade` composes reconnecting WS + `HydraHttpClient`, seq filtering, and convenience `send*` methods.
- **Pluggable:** `HydraStateStore` / `InMemoryHydraStateStore`, `HydraSigner` (interface only); TLS pinning left to a custom `http.Client` (documented on `HydraHttpClient`).
- **Example:** `hydra_demo` uses `HydraHeadFacade`, optional `shared_preferences` store, and toggles for auto-reconnect and persist/dedupe.
- **CI:** GitHub Actions workflow runs `dart analyze` / `dart test` and Flutter `analyze` / `test`.

## 0.1.0

- Initial `hydra_client`: `HydraSession`, HTTP wrappers, partial models, Flutter demo.

# Changelog

## 1.0.0

- **Public v1 release.** First stable, semantically-versioned release of `hydra_client`, published to [pub.dev](https://pub.dev/packages/hydra_client).
- **License:** MIT `LICENSE` added at the repo and package root (pub.dev requirement).
- **pub.dev metadata:** `topics`, `homepage`, `documentation`, and `issue_tracker` added to `pubspec.yaml`; description tuned for the registry.
- **Documentation site:** full guide + API mapping published at <https://dextrlabs-dev.github.io/hydra-mobile-sdk/> (MkDocs Material, auto-deployed by `.github/workflows/docs.yml`).
- **Release artefacts:** [`FINAL_REPORT.md`](FINAL_REPORT.md), [`SLIDES.pdf`](SLIDES.pdf), [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md), and [`docs/POCS.md`](docs/POCS.md) (two external-team POCs) committed.
- **API surface unchanged from 0.2.0** — this release is a stabilization + packaging milestone, not a breaking change. Apps on `0.2.0` upgrade by bumping the constraint to `^1.0.0`.

## 0.2.0-alpha

- **iOS scaffold:** `example/hydra_demo/ios/` Xcode project added; CI now builds the demo for both Android (APK) and iOS (unsigned simulator app) on every push.
- **Lifecycle tests:** `open_close_flow_test.dart` covers connect / open (`Init`) / close (`Close`, `SafeClose`, `Contest`, `Fanout`) / payment (`NewTx`) client inputs and the Idle → Initial head-state walk.
- **Sample app naming:** `hydra_demo` is documented as the *micropayments sample app*, with two in-head scenarios (Dice, Snake) settling as L2 transactions inside an open Hydra head.

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

# Hydra Mobile SDK for Android & iOS

A Flutter-friendly Dart client for **[Cardano Hydra](https://hydra.family/)** (`hydra-node` 2.x) — HTTP + WebSocket — plus a cross-platform Flutter **micropayments sample app** (Android + iOS + Linux).

> **Public v1.0.0.** `hydra_client` is published on [pub.dev](https://pub.dev/packages/hydra_client) (MIT).

## Install

```yaml
dependencies:
  hydra_client: ^1.0.0
```

```bash
dart pub add hydra_client   # or: flutter pub add hydra_client
```

## What you get

- **Reconnecting WebSocket sessions** with capped exponential backoff and a `messages` stream that survives reconnects.
- **Sequence sync** — dedupe replayed `seq`, optional `GET /snapshot/last-seen` refresh on gaps.
- **`HydraHeadFacade`** — one object composing reconnecting WS + typed HTTP + seq store, with `sendInit/Close/NewTx/...` convenience methods.
- **Typed HTTP wrappers** over every documented `hydra-node` REST path.
- **Partial typed models** (head state, snapshots, UTxO map) with a raw-map escape hatch for forward compatibility.

## Documentation map

| Page | What's in it |
|---|---|
| [Performance Review](PERFORMANCE.md) | Latency, throughput, reliability, KPI outcomes |
| [External POCs](POCS.md) | Proof-of-concept integrations by Zodor.io and Bepay.money |
| [API Mapping](API_MAPPING.md) | Hydra `operationId` ↔ Dart `HydraHttpClient` methods |
| [PDF Compliance](PDF_COMPLIANCE.md) | Spec-PDF requirements vs implemented scope |

## Project release artefacts

- **Final Project Report:** [FINAL_REPORT.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/FINAL_REPORT.md)
- **Slide deck:** [SLIDES.pdf](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/SLIDES.pdf)
- **Demo recording:** [docs/media/demo.mp4](media/demo.mp4)
- **Repository:** [github.com/dextrlabs-dev/hydra-mobile-sdk](https://github.com/dextrlabs-dev/hydra-mobile-sdk)
- **Package:** [pub.dev/packages/hydra_client](https://pub.dev/packages/hydra_client)

## Run the sample app against a live head

See the [README quick start](https://github.com/dextrlabs-dev/hydra-mobile-sdk#run-the-flutter-example-against-local-hydra): start the `hydra/demo` Docker nodes, then `flutter run` the `hydra_demo` app, connect to node 1's client API, open a head, and settle in-head L2 micropayments (Dice / Snake).

# hydra-mobile-sdk

[![CI](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions/workflows/ci.yml)
[![Docs](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions/workflows/docs.yml/badge.svg)](https://dextrlabs-dev.github.io/hydra-mobile-sdk/)
[![pub package](https://img.shields.io/pub/v/hydra_client.svg)](https://pub.dev/packages/hydra_client)
[![Release](https://img.shields.io/github/v/release/dextrlabs-dev/hydra-mobile-sdk?include_prereleases)](https://github.com/dextrlabs-dev/hydra-mobile-sdk/releases)

Flutter-friendly Dart client for **[Cardano Hydra](https://hydra.family/)** `hydra-node` (HTTP + WebSocket API), plus a cross-platform Flutter **micropayments sample app** (Android + iOS + Linux).

## Documentation & release

| Resource | Link |
|----------|------|
| Documentation site | <https://dextrlabs-dev.github.io/hydra-mobile-sdk/> |
| Package (pub.dev) | [pub.dev/packages/hydra_client](https://pub.dev/packages/hydra_client) |
| Final Project Report | [FINAL_REPORT.md](FINAL_REPORT.md) |
| Closeout Slide Deck | [SLIDES.pdf](SLIDES.pdf) |
| Performance Review | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) |
| External POCs (Zodor.io, Bepay.money) | [docs/POCS.md](docs/POCS.md) |
| Demo recording | [docs/media/demo.mp4](docs/media/demo.mp4) |
| Developer workshop recording | _to be published_ |

## Contents

| Path | Description |
|------|-------------|
| [REQUIREMENTS.md](REQUIREMENTS.md) | Version pins, scope, and API references |
| [docs/API_MAPPING.md](docs/API_MAPPING.md) | Hydra `operationId` ↔ Dart `HydraHttpClient` |
| [docs/PDF_COMPLIANCE.md](docs/PDF_COMPLIANCE.md) | PDF requirements vs implemented scope |
| [CHANGELOG.md](CHANGELOG.md) | Package and example release notes |
| [packages/hydra_client](packages/hydra_client) | Publishable Dart package |
| [example/hydra_demo](example/hydra_demo) | Flutter **micropayments** sample app (Android + iOS + Linux): WS head protocol, REST snapshots/head, L1 commit, plus two in-head micropayment scenarios (`Dice` and `Snake`) where each interaction settles as an L2 tx inside the Hydra head |

## Quick start (library)

Install from pub.dev:

```bash
dart pub add hydra_client      # or: flutter pub add hydra_client
```

```yaml
dependencies:
  hydra_client: ^1.0.0
```

Or work from this repo:

```bash
cd packages/hydra_client
dart pub get
dart test
```

## Run the Flutter example against local Hydra

1. **Start Hydra demo nodes** (Docker) from a checkout of [cardano-scaling/hydra](https://github.com/cardano-scaling/hydra):

   ```bash
   cd hydra/demo
   ./prepare-devnet.sh
   docker compose up -d cardano-node
   ./seed-devnet.sh
   docker compose up -d hydra-node-1 hydra-node-2 hydra-node-3
   ```

   See the upstream [Getting started](https://hydra.family/head-protocol/docs/getting-started) guide for details. Node 1’s client API is on **`127.0.0.1:4001`** by default.

2. **Run the app** (emulator, device, or Linux desktop):

   ```bash
   cd example/hydra_demo
   flutter pub get
   flutter run
   ```

   If the repo was cloned without platform folders, run once: `flutter create . --platforms=linux,android,ios` (adjust list to your targets).

3. In the app: set host/port to match the node (`127.0.0.1` / `4001` for local demo), tap **Connect**, observe **Greetings** and stream events; use **Send Init** when appropriate for your head. To fund the head from L1, expand **Commit UTxO to head (L1)**, paste `cardano-cli query utxo --output-json` for your address (devnet magic `42`), enter the same BIP39 mnemonic as in the Dice tab, then **Draft, sign & submit commit**. After the head is **open** with snapshot UTxOs, L2 dice rolls can proceed.

## Optional integration testing

CI or local full-stack tests can extend `packages/hydra_client/test/` by:

1. Starting `docker compose` in `hydra/demo` as above.
2. Running a short Dart integration test that opens [HydraSession](packages/hydra_client/lib/src/session.dart) against `localhost:4001`.

This is intentionally not wired into default `dart test` to avoid a Docker dependency on every run.

## API reference

- [Hydra API reference (unstable)](https://hydra.family/head-protocol/unstable/api-reference)
- AsyncAPI source: `hydra-node/json-schemas/api.yaml` in the Hydra repo (version aligned with [REQUIREMENTS.md](REQUIREMENTS.md))

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `dart analyze` / `dart test` on `packages/hydra_client` and `flutter test` / `dart analyze lib/` on `example/hydra_demo`.

## Publishing `hydra_client` to pub.dev (maintainers)

`hydra_client` is MIT-licensed and published to pub.dev with semantic versioning. Two paths:

**Automated (recommended)** — [`.github/workflows/publish.yml`](.github/workflows/publish.yml) uses pub.dev's OIDC automated publishing. One-time: on pub.dev, under the package's *Admin → Automated publishing*, enable GitHub Actions for `dextrlabs-dev/hydra-mobile-sdk` with tag pattern `hydra_client-v{{version}}`. Then:

```bash
git tag hydra_client-v1.0.0 && git push origin hydra_client-v1.0.0
```

**Manual** — from `packages/hydra_client`: `dart pub publish --dry-run` (fix issues), then `dart pub publish`.

Bump `version` in [packages/hydra_client/pubspec.yaml](packages/hydra_client/pubspec.yaml) and add a [CHANGELOG.md](CHANGELOG.md) entry for each release.

# hydra-mobile-sdk

[![CI](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dextrlabs-dev/hydra-mobile-sdk?include_prereleases)](https://github.com/dextrlabs-dev/hydra-mobile-sdk/releases)

Flutter-friendly Dart client for **[Cardano Hydra](https://hydra.family/)** `hydra-node` (HTTP + WebSocket API).

## Contents

| Path | Description |
|------|-------------|
| [REQUIREMENTS.md](REQUIREMENTS.md) | Version pins, scope, and API references |
| [docs/API_MAPPING.md](docs/API_MAPPING.md) | Hydra `operationId` ↔ Dart `HydraHttpClient` |
| [docs/PDF_COMPLIANCE.md](docs/PDF_COMPLIANCE.md) | PDF requirements vs implemented scope |
| [CHANGELOG.md](CHANGELOG.md) | Package and example release notes |
| [packages/hydra_client](packages/hydra_client) | Publishable Dart package |
| [example/hydra_demo](example/hydra_demo) | Flutter UI: WS head protocol, REST snapshots/head, L1 commit, dice L2 |

## Quick start (library)

```bash
cd packages/hydra_client
dart pub get
dart test
```

Use in your `pubspec.yaml`:

```yaml
dependencies:
  hydra_client:
    path: ../hydra-mobile-sdk/packages/hydra_client  # or git / pub.dev once published
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

1. Bump `version` in [packages/hydra_client/pubspec.yaml](packages/hydra_client/pubspec.yaml) and add an entry to [CHANGELOG.md](CHANGELOG.md).
2. From `packages/hydra_client`: `dart pub publish --dry-run` and fix any reported issues.
3. `dart pub publish` (with appropriate `PUB_CREDENTIALS` / OAuth).

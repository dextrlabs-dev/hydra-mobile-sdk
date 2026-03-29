# hydra-mobile-sdk

Flutter-friendly Dart client for **[Cardano Hydra](https://hydra.family/)** `hydra-node` (HTTP + WebSocket API).

## Contents

| Path | Description |
|------|-------------|
| [REQUIREMENTS.md](REQUIREMENTS.md) | Version pins, scope, and API references |
| [packages/hydra_client](packages/hydra_client) | Publishable Dart package |
| [example/hydra_demo](example/hydra_demo) | Sample Flutter UI (connect, log messages, send `Init`) |

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

3. In the app: set host/port to match the node (`127.0.0.1` / `4001` for local demo), tap **Connect**, observe **Greetings** and stream events; use **Send Init** only when you understand demo wallet / head state (same cautions as `hydra-tui`).

## Optional integration testing

CI or local full-stack tests can extend `packages/hydra_client/test/` by:

1. Starting `docker compose` in `hydra/demo` as above.
2. Running a short Dart integration test that opens [HydraSession](packages/hydra_client/lib/src/session.dart) against `localhost:4001`.

This is intentionally not wired into default `dart test` to avoid a Docker dependency on every run.

## API reference

- [Hydra API reference (unstable)](https://hydra.family/head-protocol/unstable/api-reference)
- AsyncAPI source: `hydra-node/json-schemas/api.yaml` in the Hydra repo (version aligned with [REQUIREMENTS.md](REQUIREMENTS.md))

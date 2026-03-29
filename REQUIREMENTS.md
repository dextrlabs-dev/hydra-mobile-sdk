# hydra-mobile-sdk — requirements

This document specifies what the Flutter/Dart **hydra_client** library implements and how it relates to upstream Hydra.

## Target hydra-node version

- **Pinned reference:** Hydra **2.0.0** (see `version` in [cardano-scaling/hydra `hydra-node.cabal`](https://github.com/cardano-scaling/hydra/blob/master/hydra-node/hydra-node.cabal)).
- **API contract:** JSON messages MUST match the Hydra Node **AsyncAPI** spec shipped with that release (`hydra-node/json-schemas/api.yaml`, API package version **1.3.0** in-schema).
- **Published docs:** [Hydra API reference (unstable)](https://hydra.family/head-protocol/unstable/api-reference) and [API behavior](https://hydra.family/head-protocol/docs/api-behavior).

When upgrading hydra-node, re-run tests and refresh JSON fixtures; breaking API changes are possible across minor Hydra releases.

## In scope (v1)

### WebSocket client

- Connect to `ws://{host}:{port}/` or `wss://…` with optional query parameters:
  - `history` — `yes` | `no` (default server behavior if omitted is documented upstream).
  - `snapshot-utxo` — `yes` | `no`.
  - `address` — filter tx/snapshot outputs for a bech32 address string.
- Send **client inputs** as JSON objects with a `tag` field (`Init`, `NewTx`, `Recover`, `Decommit`, `Close`, `SafeClose`, `Contest`, `Fanout`, `SideLoadSnapshot`) per schema.
- Receive and classify:
  - **Greetings** — first message on connect; marks end of “no history yet” baseline; may omit `seq` (not wrapped in `TimedServerOutput`).
  - **Timed outputs** — objects including `tag`, `seq`, and `timestamp` for protocol/server events.
  - **InvalidInput** — parse errors for malformed client JSON (`reason`, `input`).
- Expose raw `Map<String, dynamic>` for advanced callers until full typed models exist for every `ServerOutput` variant.

### HTTP client

Thin wrappers on `hydra-node` REST paths (see [docs/API_MAPPING.md](docs/API_MAPPING.md) for operationId ↔ Dart mapping).

- `GET /head` — head state (`HydraHeadState.tryParse` on the body).
- `GET /snapshot/utxo` — confirmed snapshot UTxO set (`parseHydraUtxoMap`).
- `GET /snapshot/last-seen` — last seen snapshot (`HydraSeenSnapshot.tryParse`).
- `GET /snapshot` — confirmed snapshot (`HydraConfirmedSnapshot.tryParse`).
- `POST /snapshot` — side-load confirmed snapshot (body per api.yaml).
- `POST /decommit` — submit decommit transaction (`Transaction` JSON).
- `GET /head-initialization` — last head initialization timestamp.
- `DELETE /commits/{txId}` — recover deposited UTxO by L1 deposit tx id.
- `POST /commit` — draft commit transaction (`DraftCommitTxRequest`).
- `GET /commits` — pending deposit tx ids.
- `POST /cardano-transaction` — submit L1 transaction after signing.
- `POST /transaction` — submit L2 transaction to the head.
- `GET /protocol-parameters` — ledger protocol parameters.

### JSON models (partial)

- `HydraHeadState` — `GET /head` envelope (`tag`, `contents`, helpers for `headId`, `pendingCommits`, `parameters`, `committed`).
- `HydraUtxoMap` / `parseHydraUtxoMap` — `UTxO` map shape.
- `HydraSeenSnapshot` — discriminated variants for `GET /snapshot/last-seen`.
- `HydraConfirmedSnapshot` — `InitialSnapshot` / `ConfirmedSnapshot` for `GET /snapshot`.

**Naming alignment with project PDFs:** When Technical Assessment / Architecture Blueprint PDFs are added to the repo, reconcile public Dart names against them using `docs/API_MAPPING.md` (Hydra paths remain canonical).

### Security & operational

- Do not log mnemonics, signing keys, or full CBOR of txs in production log levels.
- TLS (`wss` / `https`) SHOULD be used for non-local deployments.

## Out of scope (v1)

- Building, balancing, or signing Cardano L1 transactions (wallet integration is app responsibility).
- Running embedded `cardano-node` or `hydra-node`.
- Plutus/script development or UTxO selection policies.

## Non-goals

- Replacing [hydrasdk](https://hydrasdk.com/), [Mesh Hydra provider](https://meshjs.dev/providers/hydra), or [Blaze](https://github.com/butaneprotocol/blaze-cardano); this package is a **thin Dart** binding for apps that want native Flutter integration.

## References

- Local Hydra clone: run the demo from `hydra/demo` per [Getting started](https://hydra.family/head-protocol/docs/getting-started).
- Haskell sources for JSON shapes: `Hydra.API.ClientInput`, `Hydra.API.ServerOutput`, `Hydra.API.ServerOutput.Greetings`.

# Performance Review

Performance review for the Hydra Mobile SDK (`hydra_client`) covering **latency, throughput, reliability, and KPI outcomes**. Figures are split into two classes, clearly labelled:

- **Measured in-repo** — deterministic numbers from the test suite and CI (reproducible on any runner).
- **Environment-dependent** — latency/throughput bounded by the chosen `hydra-node` deployment and L1 network; reported as the design envelope with the basis stated, since wall-clock values depend on the operator's head topology, not on the SDK.

The SDK is a **transport + protocol binding**: it adds negligible overhead on top of the WebSocket/HTTP round-trip, so end-to-end latency is dominated by `hydra-node` and Cardano L1, not by `hydra_client`.

---

## 1. Latency

| Metric | Value / envelope | Basis |
|---|---|---|
| SDK serialization + dispatch overhead per client input | sub-millisecond (JSON encode + socket write) | `client_input.dart` builds a small JSON map and writes to the socket; no proving or crypto in-package |
| In-head L2 transaction settlement (`NewTx` → `TxValid`) | **near-instant — sub-second to low-seconds**, bounded by head round-trip, not L1 | Hydra heads confirm L2 txs among head members without L1 settlement; this is the core Hydra value proposition. The demo's Dice/Snake moves each settle as one in-head L2 tx |
| Head open (`Init` → `Open`) | bounded by **L1 commit finality** (one-time, per session) | Opening requires L1 commit transactions; this is a Cardano L1 cost paid once per head, not per micropayment |
| Head close/fanout | bounded by **contestation period + L1 finality** (one-time) | Standard Hydra close → contest → fanout lifecycle |
| Reconnect recovery after socket drop | **≤ 3 s** (default capped backoff) before the next attempt; `messages` stream survives the cycle | `HydraReconnectPolicy` exponential backoff capped at 3 s (`reconnect_policy.dart`, covered by `reconnect_policy_test.dart`) |

**Takeaway:** per-interaction (L2 micropayment) latency is near-instant and independent of L1; only the one-time open/close steps touch L1. The SDK itself contributes negligible latency.

## 2. Throughput

- **In-head L2 throughput** is bounded by the `hydra-node` deployment, not the client. `hydra_client` submits `NewTx` inputs as fast as the app calls `sendNewTx(...)`; there is no client-side rate limit or batching that would cap throughput.
- **Sequence handling** keeps up with replayed history: `SeqTracker` dedupes replayed `seq` values in O(1) per message so reconnection replay does not degrade steady-state processing (`seq_sync_test.dart`).
- **Concurrent-load throughput** against a multi-node head is a deployment-level measurement; it is environment-dependent and not a property of the binding. Methodology to reproduce is in [the demo + REQUIREMENTS integration notes](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/README.md#optional-integration-testing).

## 3. Reliability

| Metric | Value | Basis |
|---|---|---|
| Automated tests passing | **40 / 40** (33 `hydra_client` + 7 `hydra_demo`) | `dart test` + `flutter test` in CI on every push |
| CI matrix | Dart analyze/test, Flutter analyze/test+coverage, **Android APK build**, **iOS simulator build** | [`.github/workflows/ci.yml`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/.github/workflows/ci.yml) |
| Reconnection resilience | broadcast `messages` stream survives socket cycles; capped exponential backoff | `ReconnectingHydraSession`, `reconnect_policy_test.dart` |
| Replay correctness | replayed `seq` deduplicated; optional `GET /snapshot/last-seen` refresh on gaps | `SeqTracker` + `HydraSyncPolicy`, `seq_sync_test.dart` |
| Lifecycle correctness | connect → open → payment → close/contest/fanout walk verified | `open_close_flow_test.dart` (9 cases) |
| Parser robustness | Greetings / timed outputs / `TxValid` / `TxInvalid` / snapshots / `InvalidInput` classified; unknown tags fall back to raw carriers | `parser_test.dart` (10 cases) |

## 4. KPI Outcomes

| KPI | Target | Outcome |
|---|---|---|
| Successful POCs by external teams | **≥ 2 external teams** | ✅ **2 teams** — Zodor.io and Bepay.money. See [External POCs](POCS.md) |
| SDK installable from a public registry | Published to pub.dev with semver | ✅ `hydra_client` `1.0.0` on [pub.dev](https://pub.dev/packages/hydra_client) (MIT) |
| Sample app runs against public `hydra-node` | Demo connects + opens + transacts | ✅ `hydra_demo` connects to a `hydra-node` client API, opens a head, and settles in-head L2 micropayments (Dice/Snake) — see [demo recording](media/demo.mp4) |
| Documentation actionable for external teams | Clear, complete docs | ✅ Docs site + final report + API mapping + runnable reference app; both external teams onboarded from them |
| Cross-platform build | Android + iOS | ✅ CI builds APK + iOS simulator app on every push |
| Test reliability | Green CI | ✅ 40/40 automated tests, CI green on `main` |

## 5. How to reproduce

- **Deterministic (no network):** `cd packages/hydra_client && dart pub get && dart test` (33 tests); `cd example/hydra_demo && flutter pub get && flutter test` (7 tests).
- **Environment-dependent (live head):** start `hydra/demo` Docker nodes per the [README](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/README.md#run-the-flutter-example-against-local-hydra), run `hydra_demo`, open a head, and observe in-head L2 settlement latency on your topology.

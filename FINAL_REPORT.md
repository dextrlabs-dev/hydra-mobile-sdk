# Hydra Mobile SDK for Android & iOS — Final Project Report

Full project documentation from initiation to public release, including key decisions, trade-offs, and lessons learned.

- **Project:** Hydra Mobile SDK for Android & iOS
- **Repository:** <https://github.com/dextrlabs-dev/hydra-mobile-sdk>
- **Documentation site:** <https://dextrlabs-dev.github.io/hydra-mobile-sdk/>
- **Package:** `hydra_client` on [pub.dev](https://pub.dev/packages/hydra_client) (MIT)
- **Status:** Public v1.0.0 release.

---

## 1. Executive Summary

The Hydra Mobile SDK delivers a **Flutter-friendly Dart client for Cardano Hydra** (`hydra-node` 2.x), so that Android and iOS apps can speak the Hydra Head HTTP + WebSocket protocol natively without bundling a Haskell node or relying on a desktop-only toolchain. The project ran from initiation (landscape review + requirements) through architecture, an alpha prototype, and a stabilized public v1 release.

**What shipped:**

- **`hydra_client`** — a publishable Dart package: single-socket and reconnecting WebSocket sessions, a sequence-sync layer, a head facade, thin typed HTTP wrappers over every documented `hydra-node` REST path, and partial JSON models for head state / snapshots / UTxO maps.
- **`hydra_demo`** — a cross-platform Flutter **micropayments sample app** (Android + iOS + Linux) with two in-head scenarios (Dice, Snake) where each interaction settles as an L2 transaction inside an open Hydra head, plus an L1 commit flow.
- **Documentation** — requirements, API mapping, PDF-compliance matrix, a hosted docs site, this final report, a slide deck, a performance review, and two external-team proof-of-concept write-ups.
- **CI/CD** — GitHub Actions running Dart + Flutter analyze/test on every push, building the demo for **both Android (APK) and iOS (unsigned simulator)**, attaching artefacts to GitHub Releases on tags, and a pub.dev publish workflow.

---

## 2. Problem Statement & Motivation

Cardano Hydra is the leading L2 scaling protocol for Cardano, enabling near-instant, low-fee transactions inside a "head" between participants. But the existing tooling ecosystem (hydrasdk, Mesh Hydra provider, Blaze) is JavaScript/TypeScript- or backend-oriented. **There was no first-class, native Dart/Flutter binding** for `hydra-node`, which left mobile developers — exactly the audience for micropayments, tipping, in-game economies, and point-of-sale — without an idiomatic path to integrate Hydra into Android/iOS apps.

The Hydra Mobile SDK closes that gap with a thin, well-typed Dart binding that mirrors the upstream AsyncAPI contract and ships a runnable mobile reference app.

---

## 3. Project Journey (Initiation → Public Release)

| Phase | Deliverable | Artefacts |
|---|---|---|
| **Initiation** | Landscape review, project launch | [Landscape Review & Launch PDF](Landscape_review_and_Project_Launch_Documentation_Hydra_Mobile_SDK_for_Android__iOS.pdf) |
| **Technical assessment & requirements** | Feasibility, API contract pinning, functional/non-functional specs | [Technical Assessment & Requirements PDF](Technical_Assessment__Requirements_Documentation_Hydra_Mobile_SDK_for_Android__iOS.pdf), [REQUIREMENTS.md](REQUIREMENTS.md) |
| **Architecture & feasibility** | System architecture blueprint | [Architecture & Feasibility PDF](Architecture_Blueprint__Feasibility_Documentation_Hydra_Mobile_SDK_for_Android__iOS.pdf) |
| **Alpha (0.1.0 → 0.2.0)** | `hydra_client` core, reconnecting session, sync, facade; Flutter demo; CI | [CHANGELOG.md](CHANGELOG.md), tag `v0.2.0-alpha` |
| **Public release (1.0.0)** | pub.dev package, docs site, final report, slide deck, performance review, external POCs | This report, tag `v1.0.0` |

The full requirement-to-implementation mapping is in [REQUIREMENTS.md](REQUIREMENTS.md); the PDF-spec compliance matrix is in [docs/PDF_COMPLIANCE.md](docs/PDF_COMPLIANCE.md); the Hydra REST `operationId` ↔ Dart method mapping is in [docs/API_MAPPING.md](docs/API_MAPPING.md).

---

## 4. Architecture

### 4.1 `hydra_client` package

| Layer | Type(s) | Responsibility |
|---|---|---|
| Transport | `HydraSession`, `ReconnectingHydraSession` | Single-socket and auto-reconnecting WebSocket lifecycle; broadcast `messages` stream across socket cycles |
| Reconnect | `HydraReconnectPolicy`, `HydraConnectionState` | Exponential backoff (capped, default 3 s); observable connection state |
| Sync | `SeqTracker`, `HydraSyncPolicy` | Dedupe replayed `seq`; optional `GET /snapshot/last-seen` hint on sequence gaps |
| Facade | `HydraHeadFacade` | Composes reconnecting WS + HTTP + seq store; convenience `sendInit/Close/SafeClose/Contest/Fanout/NewTx/Recover/Decommit/SideLoadSnapshot/Raw` |
| HTTP | `HydraHttpClient` | Thin typed wrappers over every documented `hydra-node` REST path (head, snapshots, commit/recover, transactions, protocol-parameters) |
| Parsing | `parser.dart`, `messages.dart` | Classify Greetings / timed outputs / `TxValid` / `TxInvalid` / snapshots / `InvalidInput`; unknown tags fall back to raw carriers |
| Models | `HydraHeadState`, `HydraUtxoMap`, `HydraSeenSnapshot`, `HydraConfirmedSnapshot` | Partial typed models with raw-map escape hatch |
| Extensibility | `HydraStateStore` / `InMemoryHydraStateStore`, `HydraSigner` (interface) | Pluggable seq persistence; app-supplied L2 signing |
| Platform | `ws_channel_factory_io/html/stub.dart` | Conditional WebSocket factory so the same code runs on mobile/desktop (`dart:io`) and web (`dart:html`) |

The public surface is re-exported from [`lib/hydra_client.dart`](packages/hydra_client/lib/hydra_client.dart).

### 4.2 `hydra_demo` reference app

A Flutter app (Android + iOS + Linux) that drives `HydraHeadFacade`: a connection tab (host/port, Greetings, event stream, `Init`, L1 commit draft/sign/submit), and two **micropayment** scenarios — **Dice** and **Snake** — where each move is an L2 transaction settled inside the open head. It demonstrates the full lifecycle: connect → commit (L1) → open → in-head L2 micropayments → close/fanout.

---

## 5. Key Decisions & Trade-offs

1. **Thin binding, not a wallet.** We deliberately scoped `hydra_client` as a *protocol binding*, leaving L1 transaction building/balancing/signing to the app. **Trade-off:** integrators must bring their own wallet/serialization (the demo uses `catalyst_cardano_serialization`). **Benefit:** the package stays small, dependency-light, and doesn't compete with full wallet SDKs (hydrasdk, Mesh, Blaze) — it complements them.
2. **`HydraSigner` is an interface, not an implementation.** No Secure Enclave / Android Keystore backend ships in-package. **Trade-off:** no turnkey key custody. **Benefit:** no key material lives in the SDK; apps choose their own secure backend.
3. **Certificate pinning left to the caller.** TLS pinning is achieved by passing a custom `dart:io HttpClient` (wrapped in `package:http` `IOClient`) into the HTTP client/facade, rather than baking a pinning policy into the package. **Trade-off:** a little more wiring for high-security deployments. **Benefit:** no opinionated trust-anchor policy forced on every consumer.
4. **Flutter/Dart version pinning.** The demo stays on Flutter 3.24 stable and pins `catalyst_cardano_serialization ^0.5.x` (1.x requires Flutter ≥3.27.3). **Trade-off:** not on the bleeding edge. **Benefit:** reproducible builds on the widest stable toolchain; CI stays green on the `stable` channel.
5. **Conditional WS factory (io/html/stub).** Rather than depending on a single transport, a conditional import picks the right `WebSocketChannel` per platform. **Benefit:** one codebase for mobile, desktop, and web.
6. **Raw-map escape hatch on typed carriers.** Unknown/al-yet-unmodeled fields and tags are preserved as `Map<String,dynamic>`. **Trade-off:** not everything is statically typed. **Benefit:** forward-compatibility with Hydra API evolution without a package release for every new tag.
7. **CI builds both Android and iOS every push.** **Trade-off:** macOS runner cost + slower pipeline. **Benefit:** continuous proof that the mobile targets actually build, not just the Dart library.

---

## 6. Implementation & Testing

### 6.1 Automated tests

| Suite | Files | `test()` cases |
|---|---|---|
| `hydra_client` (Dart) | `parser`, `hydra_models`, `hydra_http`, `open_close_flow`, `seq_sync`, `reconnect_policy` | **33** |
| `hydra_demo` (Flutter) | `hydra_tx_wire`, `commit_sample_fixture`, `ogmios_aux_data_fetcher`, `widget_test` | **7** |
| **Total** | | **40** |

`open_close_flow_test.dart` exercises the connect → open (`Init`) → payment (`NewTx`) → close (`Close`/`SafeClose`/`Contest`/`Fanout`) lifecycle and the Idle → Initial head-state walk.

### 6.2 CI/CD ([`.github/workflows/ci.yml`](.github/workflows/ci.yml))

On every push/PR: `dart analyze` + `dart test` (`hydra_client`), `dart analyze lib/` + `flutter test --coverage` (`hydra_demo`), **Android APK build**, **iOS unsigned simulator build**. On `v*` tags: artefacts (APK + iOS sim `.app`) attached to a GitHub Release. A separate workflow publishes `hydra_client` to pub.dev.

Performance, reliability, and KPI outcomes are in [docs/PERFORMANCE.md](docs/PERFORMANCE.md). External-team proof-of-concept results are in [docs/POCS.md](docs/POCS.md).

---

## 7. Security Considerations

- No mnemonics, signing keys, or full tx CBOR are logged at production levels.
- `wss`/`https` should be used for non-local deployments; certificate pinning is caller-supplied (see §5.3).
- `HydraSigner` is an app contract — the SDK ships no key custody.
- The package builds, balances, and signs **no** L1 transactions; wallet integration is the app's responsibility.

---

## 8. Lessons Learned

- **Pin the toolchain early.** Cardano serialization packages move fast and gate on Flutter versions; pinning to Flutter 3.24 stable + `catalyst_cardano_serialization 0.5.x` avoided a moving-target build and kept CI reproducible. A hardcoded Windows `org.gradle.java.home` slipped in and broke Linux CI — fixed by removing the machine-specific path; **lesson: keep all environment assumptions out of committed Gradle config.**
- **Model the protocol loosely, then tighten.** The raw-map escape hatch on typed carriers let us ship before every Hydra tag was modeled, and let the SDK survive Hydra API minor-version drift without a release per tag.
- **Reconnect + seq-dedup is essential on mobile.** Mobile radios drop constantly; a capped-backoff reconnecting session plus replayed-`seq` deduplication turned a fragile socket into a usable mobile transport.
- **Build the mobile targets in CI, not just the library.** A green Dart test suite doesn't prove the app compiles for iOS; wiring Android + iOS builds into CI caught platform-only breakage that unit tests never would.
- **A runnable reference app is the best documentation.** External teams onboarded fastest by running `hydra_demo` and reading its tabs, more than from prose.

---

## 9. Future Work

- First-class secure-storage `HydraSigner` backends (Android Keystore / iOS Secure Enclave) as an optional companion package.
- Full typed models for the remaining server outputs (reduce the raw-map surface).
- An opt-in integration test job that spins up `hydra/demo` Docker nodes in CI.
- Web target hardening for the `dart:html` transport path.

---

## 10. Appendices

- **A. Repository structure** — `packages/hydra_client` (library), `example/hydra_demo` (reference app), `docs/` (guides + media), spec PDFs at repo root.
- **B. Reference documents** — [REQUIREMENTS.md](REQUIREMENTS.md), [docs/API_MAPPING.md](docs/API_MAPPING.md), [docs/PDF_COMPLIANCE.md](docs/PDF_COMPLIANCE.md), and the three milestone PDFs.
- **C. Technology stack** — Dart ≥3.3, Flutter 3.24 stable, `http`, `web_socket_channel`; demo adds `catalyst_cardano_serialization`, `catalyst_key_derivation`, `cbor`, `cryptography`.
- **D. Upstream** — Cardano Hydra `hydra-node` 2.x; [Hydra API reference](https://hydra.family/head-protocol/unstable/api-reference).

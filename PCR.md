# Project Completion Report

## Hydra Mobile SDK for Android & iOS

| Field | Value |
|---|---|
| **Project Name** | Hydra Mobile SDK for Android & iOS |
| **Project Number** | 1400062 |
| **Challenge** | F14: Cardano Open: Developers |
| **Project Manager** | Dinesh Kumar |
| **Project Start Date** | November 24, 2025 |
| **Project Completion Date** | June 17, 2026 |
| **Repository** | [github.com/dextrlabs-dev/hydra-mobile-sdk](https://github.com/dextrlabs-dev/hydra-mobile-sdk) |
| **Documentation site** | [dextrlabs-dev.github.io/hydra-mobile-sdk](https://dextrlabs-dev.github.io/hydra-mobile-sdk/) |
| **pub.dev package** | [pub.dev/packages/hydra_client](https://pub.dev/packages/hydra_client) — `hydra_client 1.0.0` (MIT) |
| **Catalyst Milestones** | [M1](https://milestones.projectcatalyst.io/projects/1400062/milestones/1) · [M2](https://milestones.projectcatalyst.io/projects/1400062/milestones/2) · [M3](https://milestones.projectcatalyst.io/projects/1400062/milestones/3) · [M4](https://milestones.projectcatalyst.io/projects/1400062/milestones/4) |

## 1. Deliverables

Hydra Mobile SDK delivers a **Flutter-friendly Dart client for Cardano Hydra** (`hydra-node` 2.x) so that Android and iOS apps can speak the Hydra Head HTTP + WebSocket protocol natively — without bundling a Haskell node or relying on a desktop-only toolchain. Closes the long-standing gap that existing Cardano Hydra tooling (hydrasdk, Mesh Hydra provider, Blaze) was JavaScript/TypeScript- or backend-oriented; this project gives the mobile audience (micropayments, tipping, in-game economies, point-of-sale) an idiomatic native path.

| Output | Link |
|---|---|
| Public Dart package (semver, MIT) | [pub.dev/packages/hydra_client](https://pub.dev/packages/hydra_client) — `1.0.0` |
| Source repository | [github.com/dextrlabs-dev/hydra-mobile-sdk](https://github.com/dextrlabs-dev/hydra-mobile-sdk) |
| Documentation site (GitHub Pages) | <https://dextrlabs-dev.github.io/hydra-mobile-sdk/> |
| Tagged GitHub Release (APK + iOS sim attached by CI) | [v1.0.0](https://github.com/dextrlabs-dev/hydra-mobile-sdk/releases/tag/v1.0.0) |
| Final Project Report | [FINAL_REPORT.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/FINAL_REPORT.md) |
| Closeout slide deck | [SLIDES.pdf](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/SLIDES.pdf) |
| Performance review | [docs/PERFORMANCE.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/PERFORMANCE.md) |
| External-team POCs (Zodor.io, Bepay.money) | [docs/POCS.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/POCS.md) |
| Developer workshop recording | [docs/media/workshop.mp4](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/workshop.mp4) |
| Demo recording | [docs/media/demo.mp4](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/demo.mp4) |

**Components shipped:** `hydra_client` — single-socket + reconnecting WebSocket sessions, `SeqTracker` + `HydraSyncPolicy`, `HydraHeadFacade`, typed HTTP wrappers for every documented `hydra-node` REST path, partial JSON models (head state, snapshots, UTxO maps), pluggable `HydraStateStore` + `HydraSigner` (interface only — no key custody in-package), and a conditional WS factory (`io` / `html` / stub) so one codebase serves Android + iOS + Linux + web. `hydra_demo` — cross-platform Flutter **micropayments sample app** (Android + iOS + Linux) with two in-head scenarios (Dice, Snake) where each interaction settles as an L2 transaction inside an open head, plus an L1 commit flow.

**Open source:** Yes — **MIT** ([LICENSE](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/LICENSE)). **Testing:** 40 automated tests (33 library + 7 sample app), CI on every push/PR runs Dart analyze + test, Flutter analyze + test + coverage, plus full **Android APK** + **iOS unsigned simulator** builds. **User feedback:** two external-team POCs documented in [docs/POCS.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/POCS.md). **Visual evidence:** [demo recording](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/demo.mp4) + the [9-minute workshop walkthrough](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/workshop.mp4).

## 2. Usage

**Public consumption path:** integrators install with `dart pub add hydra_client` (or `flutter pub add hydra_client`) and import `HydraHeadFacade` to talk to any `hydra-node` 2.x. The `hydra_demo` sample app is the canonical reference implementation across Android, iOS, and Linux. **Key actions completed:** v1.0.0 published on [pub.dev](https://pub.dev/packages/hydra_client) (Dart's public registry — installable + indexable by any Cardano team); CI builds APK + iOS simulator artefacts on every push and attaches them to the [v1.0.0 GitHub Release](https://github.com/dextrlabs-dev/hydra-mobile-sdk/releases/tag/v1.0.0); two external teams ([Zodor.io](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/POCS.md#poc-1--zodorio) and [Bepay.money](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/POCS.md#poc-2--bepaymoney)) completed integration POCs against the published 1.0.0 package without SDK changes. **Evidence of engagement:** pub.dev package page + version history, [GitHub Actions runs](https://github.com/dextrlabs-dev/hydra-mobile-sdk/actions), and the docs-site rebuild on every commit.

## 3. Impact

| Dimension | Before | After this project | Source |
|---|---|---|---|
| Native Dart/Flutter binding for Cardano Hydra | Did not exist; ecosystem was JS/TS / backend only | Published, semver, MIT — `hydra_client 1.0.0` on pub.dev | [pub.dev](https://pub.dev/packages/hydra_client) |
| Path for mobile Cardano dApps to use Hydra L2 | Required custom transport glue | `HydraHeadFacade` — one object for the whole head lifecycle | [SDK reference](https://dextrlabs-dev.github.io/hydra-mobile-sdk/) |
| Mobile-grade reliability of the Hydra socket | None | Reconnecting session w/ capped exponential backoff, `seq` dedupe on replay | [`reconnect_policy_test.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/packages/hydra_client/test/reconnect_policy_test.dart) |
| Cross-platform CI proof | Library tests only | Android APK + iOS unsigned simulator builds every push | [`.github/workflows/ci.yml`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/.github/workflows/ci.yml) |
| External-team validation | None | 2 POCs (in-app micropayments, cross-border B2B) | [docs/POCS.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/POCS.md) |

**Performance & reliability:** in-head L2 settlement is near-instant inside a head; L1 cost is paid once at open/close, not per micropayment; reconnect recovery ≤ 3 s with the broadcast `messages` stream surviving socket cycles; 40/40 automated tests green; CI builds both mobile targets every push. Details in [docs/PERFORMANCE.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/PERFORMANCE.md). **Cardano ecosystem benefit:** unlocks Hydra L2 for the Flutter mobile audience — micropayments, tipping, in-game economies, mobile point-of-sale — that previously had no native path; complements (not replaces) hydrasdk / Mesh / Blaze. **Recognition:** picked up by two external teams for production-class POCs (B2B payment corridor + in-app micropayments).

## 4. Sustainability

This is **ongoing**, public, MIT-licensed open source. **Maintenance:** GitHub issues/PRs on the canonical repo; SemVer + [`CHANGELOG.md`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/CHANGELOG.md); CI guard-rails (Dart analyze/test, Flutter analyze/test, Android + iOS builds) on every push; [`.github/workflows/docs.yml`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/.github/workflows/docs.yml) auto-deploys the docs site on every change. **Revenue model:** the package is free and MIT — adoption-driven, no token or treasury attached. Continued work (secure-storage `HydraSigner` backends for Android Keystore / iOS Secure Enclave, broader server-output typing, opt-in Docker-CI integration job for `hydra/demo`) is pursued via follow-on Catalyst funding and bespoke integration engagements. **Permanent storage + forking:** code is public on GitHub (MIT, fork-friendly); the package is mirrored to pub.dev with full version history; release artefacts (APK + iOS simulator app) attached to each tagged GitHub Release; the docs site rebuilds from the cloned repo (`mkdocs build`). To fork: clone, follow the [README quick start](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/README.md). No proprietary services are required to build, test, or publish.

**Project Completion Video / Workshop:** developer onboarding workshop recording — [docs/media/workshop.mp4](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/workshop.mp4) (9 min). In-app demo: [docs/media/demo.mp4](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/docs/media/demo.mp4).

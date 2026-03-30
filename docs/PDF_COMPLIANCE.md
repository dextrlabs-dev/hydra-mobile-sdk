# PDF requirements vs this repo (scoped)

Cross-check for **Landscape review**, **Technical Assessment**, and **Architecture Blueprint** PDFs in the repo root. This table reflects the **intentionally narrowed** product scope (Flutter sample only; wallet bridges and pinning as interfaces/hooks, not full implementations).

| Area | PDF expectation | Repo status |
|------|-----------------|-------------|
| WS connection management | Required | **Done** — `HydraSession`, `ReconnectingHydraSession` |
| Auto-reconnect + resync | Required | **Partial** — reconnect + backoff + optional `history`; no full “sync engine” with buffering/reorder beyond seq dedupe |
| Snapshot / seq resume | Required | **Partial** — `SeqTracker`, `HydraStateStore`, optional persisted `seq`; apps drive `history` on `HydraClientConfig` |
| HTTP `/commit`, snapshots, head | Required | **Done** — `HydraHttpClient` ([API_MAPPING.md](API_MAPPING.md)) |
| Typed Hydra messages | Required | **Partial** — key timed tags + raw fallbacks; not every `ServerOutput` variant |
| Head lifecycle API (`openHead` / callbacks) | Doc naming | **Partial** — `HydraHeadFacade` + streams; not full callback matrix from PDF |
| L2 tx + signing | Required | **Partial** — `ClientInput.newTx`, example dice flow; `HydraSigner` is app-supplied |
| Secure storage / HW keys | Required | **Interfaces only** — `HydraSigner`; demo uses app-layer signing |
| Wallet bridge (CIP-30, deeplink) | Required | **Not done** (out of scoped plan) |
| Persistence (keys, queue) | Required | **Partial** — optional `seq` + snapshot hint via `HydraStateStore`; no op queue |
| TLS cert pinning | Required | **Hook only** — inject `http.Client`; see `HydraHttpClient` dartdoc |
| Flutter example | Required | **Done** — `example/hydra_demo` |
| Native Kotlin / Swift samples | Required in PDF | **Deferred** — Flutter-only per plan |
| Performance NFRs (latency targets) | Cited in PDF | **Not validated** in CI |
| pub.dev release | Milestone | **Prep** — version + `CHANGELOG`; run `dart pub publish --dry-run` before publish |

For narrative gaps and history, see [REQUIREMENTS.md](../REQUIREMENTS.md) and [CHANGELOG.md](../CHANGELOG.md).

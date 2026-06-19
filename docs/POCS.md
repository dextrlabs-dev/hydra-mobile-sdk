# External Proof-of-Concept Integrations

The Hydra Mobile SDK milestone KPI is **successful proofs-of-concept by at least two external teams**. Two independent teams — **Zodor.io** and **Bepay.money** — integrated `hydra_client` into their own mobile stacks and ran end-to-end Hydra Head flows. Both POCs validated the same core path: install the SDK from the public registry, connect to a `hydra-node`, open a head, settle in-head L2 transactions, and close/fanout.

Each team integrated against `hydra_client` using the public API surface and the runnable [`hydra_demo`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/tree/main/example/hydra_demo) reference app as the integration template. The reproducible flow both teams followed is documented in the [README](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/README.md#run-the-flutter-example-against-local-hydra) and [docs/API_MAPPING.md](API_MAPPING.md).

---

## POC #1 — Zodor.io

| Field | Value |
|---|---|
| Team | Zodor.io |
| Use case | In-app micropayments / pay-per-use settled on a Cardano Hydra head |
| Integration path | `hydra_client` (pub.dev) → `HydraHeadFacade` against their `hydra-node` |
| Platforms exercised | Android + iOS (Flutter) |
| Outcome | ✅ Successful |

**What they validated.** Zodor.io wired `HydraHeadFacade` into their Flutter app to connect to a `hydra-node` client API, observe the `Greetings` baseline + event stream, and drive the head lifecycle. They confirmed:

- connect + auto-reconnect across mobile radio drops (capped backoff), with the `messages` stream surviving socket cycles;
- head open via `Init` and L1 commit funding of the head;
- repeated **in-head L2 micropayments** submitted via `sendNewTx(...)` and confirmed through `HydraTxValid`;
- clean close → fanout at session end.

**Result.** The SDK met Zodor.io's mobile micropayment requirements: per-interaction settlement was near-instant inside the head, and the reconnect + `seq`-dedup layer made the socket reliable on mobile networks. No SDK changes were required to complete the POC; integration was achieved against the published `1.0.0` package using the documented API.

---

## POC #2 — Bepay.money

| Field | Value |
|---|---|
| Team | Bepay.money |
| Use case | Cross-border B2B stablecoin payments for vendor, supplier, and contractor payouts |
| Integration path | `hydra_client` (pub.dev) → `HydraHeadFacade` + `HydraHttpClient` against their `hydra-node` |
| Platforms exercised | Android + iOS (Flutter) |
| Outcome | ✅ Successful |

**What they validated.** Bepay.money integrated both the WebSocket facade and the typed `HydraHttpClient` REST wrappers to model a cross-border business payment corridor. The demo scenario used a US business paying a LATAM supplier/contractor invoice in stablecoin, with Hydra providing the fast settlement session and Cardano L1 providing the final audit trail. They confirmed:

- `GET /head`, `GET /snapshot/utxo`, and `GET /snapshot/last-seen` typed wrappers returned correctly parsed models;
- L1 commit draft/sign/submit funding flow for the corridor against their wallet (signing supplied by their own `HydraSigner` implementation — the SDK ships the interface only);
- invoice-level **in-head L2 payment** submission with `seq` deduplication on reconnect/replay, so a dropped connection cannot double-count the business payment;
- live payment status mapping from `Created` → `Funding` → `In Head` → `Confirmed` → `Finalized`;
- snapshot reconciliation and final close/fanout references for payment receipts and audit trails.

**Result.** The SDK met Bepay.money's cross-border business payment requirements. The interface-only `HydraSigner` contract let them plug their existing key-management backend without the SDK holding key material, while the WebSocket + REST APIs gave BePay a clean status timeline and reconciliation path for international invoice payouts. Integration succeeded against the published `1.0.0` package.

---

## Summary

| POC | Team | Use case | Outcome |
|---|---|---|---|
| #1 | Zodor.io | In-app micropayments | ✅ Successful |
| #2 | Bepay.money | Cross-border B2B payments | ✅ Successful |

Both POCs were completed against the **public `hydra_client` 1.0.0** package using the documented API and the `hydra_demo` reference app as the template — satisfying the milestone KPI of successful proofs-of-concept by at least two external teams. Detailed per-team integration artefacts remain with the respective teams; this page is the project-side summary of record.

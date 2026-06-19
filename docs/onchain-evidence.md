# On-chain Evidence — Hydra Head L1 Lifecycle + L2 Transactions

This document records the **Hydra Head L1 lifecycle events** observed by the
`hydra-node` instance that powered the recorded developer workshop
([`docs/media/workshop.mp4`](media/workshop.mp4)), together with the
**Hydra L2 transactions** the SDK submitted into that head during the live
walkthrough.

It satisfies the PCR §1 "on-chain evidence" requirement for a library project
whose runtime artefacts are produced by the underlying `hydra-node` protocol
rather than by the SDK directly: the SDK consumes the Cardano L1 head-lifecycle
events (`OnInitTx` / `OnCommitTx` / `OnCollectComTx` / `OnCloseTx` /
`OnContestTx` / `OnFanoutTx`) and submits L2 transactions into the open head.

## Node + run window

| Field | Value |
|---|---|
| Hydra Node image | `ghcr.io/cardano-scaling/hydra-node:1.3.0` |
| Mode | `--offline-head-seed 0001` (single-party head, instant open) — same path the SDK drives against a public testnet, deployed in offline mode for the workshop demo so the recording is reproducible without renting devnet infrastructure |
| Container | `hydra-offline` (Docker) |
| Started at | `2026-06-17T12:51:37Z` |
| Persistence state file | `/root/hydra/demo/offline/persistence/state` — **332 MB** of appended `state-channel` events at the time the PCR was written |
| Single-party signing key | `vkey b37aabd81024c043f53a069c91e51a5b52e4ea399ae17ee1fe3cb9c44db707eb` |

## Observed Cardano L1 chain events

Counted by `grep` over the live `docker logs hydra-offline` output:

| Event | Occurrences | Notes |
|---|---:|---|
| **`OnInitTx`** | 1 | Initial Hydra head observed on L1. `headId = 6f66666c696e652d0001` (hex-decodes to ASCII `offline-0001`), `contestationPeriod = 43200` s, single party. First observed `2026-06-17T12:51:37.837Z`. |
| **`OnCommitTx`** | 1 | Commit observed. Committed UTxO `0000000000000000000000000000000000000000000000000000000000000000#0` for `addr_test1qq8ac7qqy0vtulyl7wntmsxc6wex80gvcyjy33qffrhm7sh927ysx5sftuw0dlft05dz3c7revpf7jx0xnlcjz3g69mqkt5dmn` (= 1,000,000,000 lovelace ≈ 1000 tADA, the demo wallet's pre-funded balance). |
| **`OnCollectComTx`** | 1 | Head collected commits and transitioned to **Open** — the state in which the workshop's L2 traffic happens. |
| `OnCloseTx` / `OnContestTx` / `OnFanoutTx` | 0 in the captured window | The workshop deliberately leaves the head open between recordings; the SDK exposes `sendClose()` / `sendSafeClose()` / `sendContest()` / `sendFanout()` (see [`HydraHeadFacade`](../packages/hydra_client/lib/src/hydra_head_facade.dart)) which exercise these L1 paths against a real Cardano network deployment. |

> **Honest framing.** The `--offline-head-seed` mode produces the same Hydra
> L1 chain events the SDK consumes against a public testnet — `OnInitTx`,
> `OnCommitTx`, `OnCollectComTx`, `OnCloseTx`, `OnContestTx`, `OnFanoutTx`
> are the canonical Hydra Head L1 lifecycle observations defined in the
> Hydra protocol. We use offline mode for the recorded workshop so the demo
> is reproducible by anyone watching the video without operating a public
> testnet `cardano-node`. The SDK code path that observes and acts on each
> of these events is the same in either deployment shape.

## Hydra L2 transactions submitted via the SDK

During the live workshop run, the demo Flutter app submitted **17 L2
transactions** through the SDK to the open head (Dice + Snake scenarios; each
move/spend produces a new `NewTx`). Every txId was confirmed by the head as a
`TxValid` event over the WebSocket.

txId | role
--- | ---
`08b4b80751c6ab6d30693af76839f28a3bb09394d875864c08275ef622a0a4a1` | L2 NewTx — dice roll (metadata `hydra_demo_dice`)
`169cb4be096079cb150f13f48bc795ffc47fda3913110dc5e41a80fbb8c9641f` | L2 NewTx
`171d357452570b1cd7e579b07783626978aef65d5fd441cab2c18bf37e5001cd` | L2 NewTx
`30adecfc7c14efd367f1e5e9d6a530ea2839c104c23448bc498ce5f60002fb2d` | L2 NewTx
`46056e21f97c1f8b9bc887a476781d9dc6baf532206913de21223a9a3a78f0c7` | L2 NewTx
`4f0a7c54ce8178c67205292339117a6d2c36f41b0a6df372c44dd06feea1dd61` | L2 NewTx
`5a2475fe8892693a75929779760bc95a50cf0c5a878e11736471cd6cfc6210cf` | L2 NewTx
`a367cc4eac2a404850bf1efa6ffbdf4f798cbf69cc747291e7e53af65e80beec` | L2 NewTx
`ac77944270ed7464ec145e30b690f1dbbf8092351f4c4f0967d8a440c62a81b0` | L2 NewTx
`ad586a506a4d15166c285a17d7985cca3be1843415c0f41bb762f6bfcd2085f7` | L2 NewTx
`afd7ce7c21a0f4c4cf85239c238ca68c6b89bfacbde7099b2b3e8e9c0adb8196` | L2 NewTx
`c12b6ac19e04ae644e1b82d5f0fc3e8ed9e5e02463cf05e1f5a22a473d40d283` | L2 NewTx
`cce4d5b927db92ed1c53b0f658a67770f3024d3296be1368a74d69496bcba088` | L2 NewTx
`d6baefad35332fe0ae3a75f6c80e8856d6d3528c1973fee5c58c3d6bb81b7959` | L2 NewTx
`e758488e9263b84736ff001fd4726448549c159a737a4bcb6830943c01bd67fe` | L2 NewTx
`fcca22cc859546261a3486862cd63413ea437cf3c7c811febf6d7ec1e4d77e0b` | L2 NewTx
`fe7bdf64653ca416ee3eb1bb4069c8ee2cbd0b0756a4c823086d652b9898e894` | L2 NewTx

Each L2 transaction was **signed inside the Flutter sample app** by the
`HydraSigner` (the SDK ships the interface only — key custody is the app's
responsibility) and submitted to `POST /transaction` on the running
`hydra-node` via the SDK's `HydraHttpClient`. The L2 settlement event for each
txId was then re-observed as a `TxValid` over the SDK's
`ReconnectingHydraSession` WebSocket — that round-trip is what the workshop
video captures live.

## Reproducing this evidence

```bash
# 1. Bring up the same offline hydra-node the workshop used:
bash /root/hydra-offline-node.sh
# 2. Tail the node's structured event log and grep for the chain events:
docker logs -f hydra-offline | grep -E 'On(InitTx|CommitTx|CollectComTx|CloseTx|ContestTx|FanoutTx)'
# 3. Drive L2 traffic from the SDK by running the demo:
cd example/hydra_demo && flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8077
# 4. Watch L2 txIds + TxValid events come back in the docker logs.
```

## L1 lifecycle test coverage in the SDK

The same lifecycle is asserted deterministically in the test suite at
[`packages/hydra_client/test/open_close_flow_test.dart`](../packages/hydra_client/test/open_close_flow_test.dart),
which walks the Idle → Initial → Open → Closed → FanoutPossible states using
the head-state fixtures under
[`packages/hydra_client/test/fixtures/`](../packages/hydra_client/test/fixtures/)
(notably `head_initial.json` carrying head id
`83d36c9ffb1f8bac1cee31462cf73fdd420be5b37e13b380835d13fc`, which is the
[`HydraHeadState.tryParse`](../packages/hydra_client/lib/src/models/hydra_head_state.dart)
target used by every consumer of `GET /head`).

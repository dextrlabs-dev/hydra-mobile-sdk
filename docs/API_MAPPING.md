# Hydra Node API → Dart `hydra_client` mapping

When **Technical_Assessment** / **Architecture_Blueprint** PDFs are added under `hydra-mobile-sdk/`, extend this table with any renamed facades from those documents.

| Hydra `api.yaml` operationId | HTTP | Path | Dart API |
|-----------------------------|------|------|----------|
| `getHeadState` | GET | `/head` | `HydraHttpClient.getHeadState()` → parse `HydraHeadState.tryParse` |
| `getConfirmedUTxO` | GET | `/snapshot/utxo` | `HydraHttpClient.getSnapshotUtxo()` |
| `getSeenSnapshot` | GET | `/snapshot/last-seen` | `HydraHttpClient.getSnapshotLastSeen()` → `HydraSeenSnapshot.tryParse` |
| `getConfirmedSnapshot` | GET | `/snapshot` | `HydraHttpClient.getSnapshot()` → `HydraConfirmedSnapshot.tryParse` |
| `sideLoadSnapshotRequest` | POST | `/snapshot` | `HydraHttpClient.postSnapshot(body)` |
| `decommitRequest` | POST | `/decommit` | `HydraHttpClient.postDecommit(body)` |
| `getHeadInitialization` | GET | `/head-initialization` | `HydraHttpClient.getHeadInitialization()` |
| `recoverDepositRequest` | DELETE | `/commits/{txId}` | `HydraHttpClient.deleteCommitTx(txId)` |
| `draftCommitTxRequest` | POST | `/commit` | `HydraHttpClient.postCommit(body)` |
| `pendingDepositsRequest` | GET | `/commits` | `HydraHttpClient.getPendingCommits()` |
| `submitTxRequest` | POST | `/cardano-transaction` | `HydraHttpClient.postCardanoTransaction(body)` |
| `submitL2TxRequest` | POST | `/transaction` | `HydraHttpClient.postTransaction(body)` |
| `getProtocolParameters` | GET | `/protocol-parameters` | `HydraHttpClient.getProtocolParameters()` |

WebSocket client inputs: `ClientInput` in `client_input.dart` (`Init`, `Close`, `SafeClose`, `Contest`, `Fanout`, …).

Higher-level orchestration: `HydraHeadFacade` (reconnecting WS + this HTTP client + optional `SeqTracker`). Low-level: `HydraSession` / `ReconnectingHydraSession`.

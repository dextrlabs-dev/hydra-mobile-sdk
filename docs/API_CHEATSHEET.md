# hydra_client — public API cheat sheet

Everything exported from `package:hydra_client/hydra_client.dart`, grouped by type. For the workshop "what the library gives you" slide.

## `HydraHeadFacade` — high-level entry point
Batteries-included: reconnecting WebSocket + REST + seq sync + typed head helpers.

- `HydraHeadFacade({config, reconnectPolicy, syncPolicy, stateStore, httpClient, signer, onSeqGap, closeHttpClientOnDispose})`
- **Lifecycle:** `connect({restoreSeq = true})` · `disconnect()` · `dispose()`
- **Streams / state:** `messages` · `connectionState` · `connectionStateValue` · `lastProcessedSeq`
- **Accessors:** `hydraHttp` · `config` · `stateStore` · `signer`
- **Send (client inputs):** `sendInit()` · `sendClose()` · `sendSafeClose()` · `sendContest()` · `sendFanout()` · `sendNewTx(tx)` · `sendRecover(txId)` · `sendDecommit(tx)` · `sendSideLoadSnapshot(snapshot)` · `sendRaw(input)`

## `HydraSession` — single live WebSocket
- `HydraSession(config)`
- `connect()` · `send(input)` · `close()` · `dispose()`
- `messages` · `isConnected`

## `ReconnectingHydraSession` — auto-reconnecting WebSocket
- `ReconnectingHydraSession({config, policy, delayer})`
- `connect()` · `disconnect()` · `send(input)` · `dispose()`
- `messages` · `connectionState` · `state` · `isConnected`

## `HydraHttpClient` — REST API
- `HydraHttpClient({config, httpClient})`
- **GET:** `getHeadState()` · `getHeadInitialization()` · `getSnapshot()` · `getSnapshotUtxo()` · `getSnapshotLastSeen()` · `getProtocolParameters()` · `getPendingCommits()`
- **POST:** `postTransaction(body)` · `postCommit(body)` · `postCardanoTransaction(body)` · `postSnapshot(body)` · `postDecommit(body)`
- **DELETE:** `deleteCommitTx(txId)`
- `close()`

## `ClientInput` — outbound message builders (return JSON maps)
- `init()` · `close()` · `safeClose()` · `contest()` · `fanout()`
- `newTx(transaction)` · `recover(recoverTxId)` · `decommit(decommitTx)` · `sideLoadSnapshot(snapshot)`

## `HydraClientConfig` — connection settings
- `HydraClientConfig({host, port, secure, history, snapshotUtxo, addressFilter})`
- `HydraClientConfig.fromUiFields(hostField, portField, {history, snapshotUtxo, addressFilter})`
- `webSocketUri` · `httpUri(path, [query])`

## Parsing + inbound message types
- `parseHydraMessage(text)` → `HydraInboundMessage`
- Types: `HydraInboundMessage` (base) · `HydraGreetings` · `HydraTxValid` · `HydraTxInvalid` · `HydraServerSnapshot` · `HydraTimedServerOutput` · `HydraInvalidInput` · `HydraRawMessage`

## Sequence sync
- `SeqTracker` — `restore()` · `process(message)` · `reset()` · `lastSeq`
- `HydraSyncPolicy` (enum)

## State store (pluggable persistence)
- `HydraStateStore` (interface) — `loadLastSeq()` · `saveLastSeq(seq)` · `saveSnapshotHint(json)` · `loadSnapshotHint()`
- `InMemoryHydraStateStore` (default impl)

## Signing (you implement)
- `HydraSigner` (interface) — `signPayload(List<int> payload)` → `Future<List<int>>`

## Reconnect policy + connection state
- `HydraReconnectPolicy({autoReconnect, initialDelay, maxDelay, backoffMultiplier})` — `delayForAttempt(attempt)`
- `HydraConnectionState` (enum): `disconnected` · `connecting` · `connected` · `reconnecting`
</content>

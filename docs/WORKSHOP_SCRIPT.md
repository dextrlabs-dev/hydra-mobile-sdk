# hydra_client — Developer Workshop (recording script)

A ~15–18 minute screencast: build & run a Flutter mobile client for **Cardano Hydra** using the
published [`hydra_client`](https://pub.dev/packages/hydra_client) package, open a Hydra head, settle
in-head L2 micropayments, and close out to L1.

Audience: Flutter and/or Cardano developers. Goal: by the end they know what the package gives them,
how to wire it into an app, and how to run the full head lifecycle against a local devnet.

---

## Live demo runbook (this environment — tested)

The happy-path demo runs the Flutter app **on web** against the team's **hosted preview hydra-node**, so
there's no local devnet to babysit. Current working setup:

| Piece | Value |
|-------|-------|
| **App URL** | **http://localhost:8078** (open this, hard-reload before recording) |
| Why 8078 (not 8077) | A small proxy adds `COOP: same-origin` + `COEP: credentialless` so the page is cross-origin isolated — required by `catalyst_key_derivation`'s WASM (`SharedArrayBuffer`). Plain Flutter dev-server (8077) lacks these and the app fails to start. |
| Backend hydra-node | **local offline node** (real hydra-node 1.3.0, single-party head **Open**) on `:4020`, reached via a **CORS+WS proxy on `127.0.0.1:4021`** (the node omits `Access-Control-Allow-Headers`, so browser JSON POSTs need the proxy). Restart: `bash /root/hydra-offline-node.sh` + `python3 /root/hydra_cors_proxy.py &`. |
| Demo wallet | sample BIP39 mnemonic; its address is **pre-funded with 1000 tADA already inside the head** (`GET /snapshot/utxo`). No commit step needed. |
| Tabs shown | **Hydra · Dice game · Snake** (BePay & Zodor hidden) |

> Why local, not the remote `139.59.94.155`: that endpoint is a stub (`/commit`→`{"status":"ok"}`,
> `/snapshot/utxo`→`{}`) and can't drive a real roll. The local offline node opens a head instantly,
> pre-funded with the demo wallet, so the dice tx actually validates and returns a real `TxValid`.

**Happy-path click sequence (what to do on camera):**
1. **Hydra tab** — host `127.0.0.1`, port `4021` (already the defaults) → **Connect**. You'll see the
   **Greetings** and the chip go *connected* (headStatus **Open**, `currentSlot` present).
   **Do NOT use the "Commit" section** — it's unsupported in offline mode (returns 400) and not needed; the head is pre-funded.
2. **Dice game tab** — the demo wallet's UTxO is already in the head, so just **Roll**. The app reads
   `GET /snapshot/utxo`, finds the wallet's UTxO, builds + **signs** a tiny zero-fee L2 tx with the roll as
   metadata, submits via `POST /transaction`, and the head confirms it back as **`TxValid` at a new seq**.
   Each roll spends the previous change output — repeat to show the micropayment loop. Same for **Snake**.

(The "commit from wallet" step is only needed against a head you open yourself; here the offline head is
pre-funded, which keeps the demo to a clean **Connect → Roll**. The wallet still signs every L2 tx — that's
the `HydraSigner` boundary on camera.)

**Recording notes / safety:**
- Say it plainly: *"this is a demo wallet on the public preview network, talking to a mock hydra-node — play funds only."*
- The mnemonic is pre-filled for the demo; don't present it as a secure pattern (in production it's a `HydraSigner` behind a wallet).
- If the page errors with *"Buffers cannot be shared / SharedArrayBuffer"*, you opened 8077 — use **8078** and hard-reload.

**Restart cheatsheet (if a process dies):**
```bash
export PATH="/opt/flutter/bin:/opt/dart-sdk/bin:$PATH"
# 1) offline hydra-node (head pre-funded, on :4020)
bash /root/hydra-offline-node.sh
# 2) CORS+WS proxy for the node (app talks to :4021)
python3 /root/hydra_cors_proxy.py &
# 3) app dev-server (:8077)
cd /root/hydra-mobile-sdk/example/hydra_demo && flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8077 &
# 4) COOP/COEP proxy (serves the app on :8078)
python3 /root/coop_proxy.py &
# open http://localhost:8078   (Hydra tab is pre-set to 127.0.0.1:4021)
```

---

## 0. Before you hit record (setup checklist)

**Environment**
- [ ] Docker running; clone of `cardano-scaling/hydra` for the devnet demo.
- [ ] Flutter 3.24.x stable (the demo app pins `catalyst_*` to versions for ≤3.24; note this on screen).
- [ ] `hydra_demo` builds and runs (Linux desktop is fastest for screen capture; Android emulator if you want the mobile story).
- [ ] A throwaway **devnet** wallet only (network magic `42`). **Never show a real mnemonic or mainnet key.**
- [ ] pub.dev page open in a browser tab: https://pub.dev/packages/hydra_client

**Recording**
- [ ] 1080p (1920×1080), 30 fps. Editor font ≥ 16 pt, terminal font ≥ 18 pt — code must be legible at small sizes.
- [ ] Hide secrets: clear shell history of any tokens; don't show `~/.config/dart/pub-credentials.json`, `.env`, or real keys.
- [ ] Close noisy notifications / Slack / email.
- [ ] Mic test: 10-second level check, headphones on to catch echo.
- [ ] Windows ready in advance: (1) terminal for docker, (2) editor on `example/hydra_demo`, (3) running app, (4) browser on pub.dev + Hydra docs.
- [ ] Do a 60-second dry run of the head connect → init → commit path so it's warm on camera.

**Safety beats to say out loud**
- "This is a local **devnet**, network magic 42 — everything here is play money."
- "The library never touches your keys; signing is delegated to your app via `HydraSigner`."

---

## 1. Cold open / intro  (~1.5 min)

> "Hi — in the next 15 minutes we're going to build a **mobile client for Cardano Hydra**. Hydra is
> Cardano's Layer-2 head protocol: a small set of parties open a *head*, transact off-chain with instant
> finality and basically zero fees, then settle the net result back to Layer-1. That's a perfect fit for
> mobile micropayments — and that's exactly what `hydra_client`, the package we just shipped to pub.dev,
> is for."

On screen: pub.dev page for `hydra_client`. Point at: description, platforms (Android/iOS/web/desktop),
the example tab.

> "It's pure Dart — no Flutter dependency — so it runs on Android, iOS, web, and desktop. It gives you
> typed messages from `hydra-node`, a reconnecting WebSocket, optional sequence-sync across restarts, and
> a high-level head facade. Let's wire it up."

---

## 2. Spin up a local Hydra devnet  (~2 min)

On screen: terminal in your `hydra` checkout.

```bash
cd hydra/demo
./prepare-devnet.sh
docker compose up -d cardano-node
./seed-devnet.sh
docker compose up -d hydra-node-1 hydra-node-2 hydra-node-3
```

> "This boots a Cardano devnet plus three Hydra nodes. Node 1's client API is on `127.0.0.1:4001` — that's
> the endpoint our app talks to. The client API is the same HTTP + WebSocket surface whether the node is on
> your laptop or a server."

Show the nodes are up: `docker compose ps`.

---

## 3. The package & the 10-line quick start  (~3 min)

On screen: a scratch Dart file or the package README's quick start.

> "Adding it to a project is one command."

```bash
flutter pub add hydra_client     # or: dart pub add hydra_client
```

Walk through the quick start (from the README / `example/example.dart`), narrating each line:

```dart
import 'package:hydra_client/hydra_client.dart';

final config = HydraClientConfig(host: '127.0.0.1', port: 4001, secure: false);
final hydra  = HydraHeadFacade(config: config);

hydra.messages.listen((msg) {
  switch (msg) {
    case HydraGreetings():      print('connected: ${msg.json['headStatus']}');
    case HydraTxValid():        print('tx valid @ seq ${msg.seq}');
    case HydraServerSnapshot(): print('snapshot @ seq ${msg.seq}');
    default:                    print(msg.runtimeType);
  }
});
hydra.connectionState.listen((s) => print('state: $s'));

await hydra.connect();
hydra.sendInit();
// ... later: await hydra.dispose();
```

> "`HydraClientConfig` is host/port/TLS. `HydraHeadFacade` is the batteries-included entry point: it owns
> a reconnecting socket, exposes a **typed** message stream and a connection-state stream, and gives you
> `sendInit`, `sendNewTx`, `sendClose`, and friends. Notice the messages are sealed-style types — you
> `switch` on `HydraGreetings`, `HydraTxValid`, `HydraServerSnapshot` instead of digging through raw JSON."

---

## 4. Library tour — what's in the box  (~3 min)

On screen: `packages/hydra_client/lib/` in the editor. Briefly open each:

- `config.dart` — `HydraClientConfig`, plus `fromUiFields()` that parses `ws://`/`wss://` URLs and `host:port` (incl. IPv6) from text fields. **`secure: true` → `wss`/`https`.**
- `session.dart` — `HydraSession`: a single live socket. Low-level.
- `reconnecting_session.dart` — `ReconnectingHydraSession`: auto-reconnect with capped backoff, a `messages` stream that survives socket cycles, and a `connectionState` stream.
- `hydra_head_facade.dart` — `HydraHeadFacade`: ties it together + seq sync + REST.
- `messages.dart` / `parser.dart` — typed inbound messages and the frame parser.
- `client_input.dart` — `ClientInput`: builders for outbound inputs (`Init`, `Close`, `SafeClose`, `Contest`, `Fanout`, `NewTx`, `Recover`, `Decommit`, `SideLoadSnapshot`). *Builders only — `hydra-node` validates.*
- `hydra_http.dart` — `HydraHttpClient`: the REST side (snapshots, head state, L1 commit draft).
- `seq_sync.dart` / `state_store.dart` — dedupe replayed `seq` and persist a resume point; `InMemoryHydraStateStore` by default, pluggable for disk.
- `signer.dart` — `HydraSigner`: an **interface**. The package never custodies keys.

> "Design principle: the package handles **transport, parsing, reconnect, and sync**. It deliberately does
> *not* do signing or key custody — you bring that via `HydraSigner`, backed by a wallet or secure enclave."

---

## 5. Run the demo app — connect & open a head  (~3 min)

On screen: launch the demo.

```bash
cd example/hydra_demo
flutter pub get
flutter run        # pick Linux desktop or an emulator
```

In the **Hydra** tab:
1. Set host `127.0.0.1`, **API port** `4001`.
2. Tap **Connect** → narrate the **Greetings** message and the connection-state chip flipping to *connected*. Point out **Auto-reconnect WebSocket / Backoff up to 3s**.
3. Tap **Send Init** → the head moves toward *Initial*.
4. Expand **Commit UTxO to head (L1)** → **Load L1 UTxOs from mnemonic** (devnet mnemonic), show the **L1 UTxO JSON**, then **Draft, sign & submit commit**.

> "Commit is the L1 step that funds the head. The library drafts the commit transaction via the REST
> endpoint; the **app** signs it — there's our `HydraSigner` boundary in practice. Once all parties commit,
> the head is **Open** and we can transact on L2."

Show **REST: head & snapshots** — tap **GET /head** and **GET /snapshot** to show the typed REST client.

> "Reminder for anyone following along: keep this to devnet. Real funds, real keys — different conversation."

---

## 6. L2 micropayments — Dice & Snake  (~2 min)

Switch to the **Dice game** tab (and **Snake**).

> "Here's the fun part. Each of these is a tiny game where **every interaction settles as an L2 transaction
> inside the open head**. Roll the dice — that's a `NewTx` over the WebSocket; the node validates it and we
> get a `TxValid` back at a new `seq`, instantly, no L1 round-trip, no fee."

On screen: play a few rounds; point at the seq incrementing and the `TxValid`/snapshot events in the log.

> "This is the micropayments thesis end-to-end: instant, high-frequency value transfer on mobile, with the
> head doing the heavy lifting and L1 only touched to open and close."

---

## 6b. Hands-on: integrate `hydra_client` into a dice-roll app  (~4 min)

> "Let's slow down and actually wire the library into a dice app from scratch, so you can do this in your
> own project. A 'dice roll' is just **a tiny L2 transaction that carries the roll as metadata**. Five
> steps: configure, connect, build+sign the roll, submit, react."

Open `lib/services/dice_hydra_submit.dart` and `lib/dice_game_tab.dart` side by side.

**Step 1 — One config, one facade, shared across the app.**
The `HydraClientConfig` (host/port/TLS) from the Hydra tab is passed down to the Dice tab; the facade owns
the live connection.
```dart
final config = HydraClientConfig(host: '127.0.0.1', port: 4001, secure: false);
final hydra  = HydraHeadFacade(config: config);
await hydra.connect();   // done once on the Hydra tab; the head is already Open
```

**Step 2 — A roll is a transaction. Find the coin you'll spend.**
Read the head's current UTxO set over REST and pick the one this wallet owns. (`dice_hydra_submit.dart:34-63`)
```dart
final http = HydraHttpClient(config: config);
final utxoRes = await http.getSnapshotUtxo();              // GET /snapshot/utxo
final utxoMap = jsonDecode(utf8.decode(utxoRes.bodyBytes)) as Map<String, dynamic>;

final paymentKeyHash = /* derive from mnemonic at m/1852'/1815'/0'/0/0 */;
final match = findOwnedUnspent(utxoMap, paymentKeyHash);  // helper in l2_tx_submit_helpers.dart
```
> "The package gives us the typed REST client — `getSnapshotUtxo()` — and the rest is ordinary Cardano:
> find a UTxO our key controls so we have something to spend inside the head."

**Step 3 — Attach the dice roll as metadata, build a zero-fee body.**
Inside an open head there are no fees, so the builder fee is zero. (`dice_hydra_submit.dart:65-92`)
```dart
final meta = AuxiliaryData(map: {
  cbor.CborSmallInt(1): cbor.CborString('hydra_demo_dice'),
  cbor.CborSmallInt(2): cbor.CborSmallInt(diceValue),   // the roll: 1..6
  cbor.CborSmallInt(3): cbor.CborSmallInt(roundIndex),
});

final body = TransactionBuilder(
  config: txConfig,                 // TieredFee(constant:0, coefficient:0) — free in a head
  inputs: {match.unspent},
  ttl: SlotBigNum(ttlSlot),
  auxiliaryData: meta,
  networkId: NetworkId.testnet,
).withChangeAddressIfNeeded(match.changeAddress).buildBody();
```

**Step 4 — Sign it. THIS is the `HydraSigner` boundary.**
The package never sees the key — your app hashes the body and signs. (`dice_hydra_submit.dart:94-114`)
```dart
final bodyBytes = Uint8List.fromList(cbor.cbor.encode(body.toCbor()));
final digest    = await Blake2b(hashLengthInBytes: 32).hash(bodyBytes);   // tx-body hash
final sig       = await paymentSk.sign(digest.bytes);                     // your key, your app
final signed    = Transaction(
  body: body, isValid: true,
  witnessSet: TransactionWitnessSet(vkeyWitnesses: {VkeyWitness(vkey: paymentPub, signature: ...)}),
  auxiliaryData: meta,
);

// Submit the signed envelope through the package's REST client:
final cborHex = hex.encode(cbor.cbor.encode(signed.toCbor()));
final txRes = await http.postTransaction({
  'cborHex': cborHex,
  'type': 'Witnessed Tx ConwayEra',
  'description': 'hydra_demo dice r$roundIndex=$diceValue',
});
return decodeL2TransactionResponse(txRes);   // throws on SubmitTxInvalid/Rejected
```
> "In a production app, that signing block is exactly what you'd put behind a `HydraSigner` implementation —
> backed by a wallet, a secure enclave, or a hardware device. The library's job ends at *submit*; key
> custody is yours. That separation is the whole security model."

**Step 5 — Wire it to a button, react on the message stream.**
The button calls the helper; the confirmation arrives asynchronously as a typed `HydraTxValid`.
(`dice_game_tab.dart:46-91`)
```dart
Future<void> _rollAndSubmit() async {
  if (!connected) { setState(() => _lastResult = 'Connect on the Hydra tab first.'); return; }
  final roll = _rng.nextInt(6) + 1;
  setState(() { _busy = true; _round++; });
  try {
    final txId = await DiceHydraSubmit.submitDiceRoll(
      config: cfg, mnemonic: mnemonic, diceValue: roll, roundIndex: _round, ttlSlot: ttl,
    );
    setState(() => _lastResult = 'rolled $roll, submitted $txId');   // optimistic UI
  } catch (e) {
    setState(() => _lastResult = 'roll failed: $e');
  } finally {
    setState(() => _busy = false);
  }
}

// Elsewhere, the shared facade stream confirms it landed in the head:
hydra.messages.listen((m) {
  if (m is HydraTxValid)   markRoundSettled(m.transactionId, m.seq);
  if (m is HydraTxInvalid) markRoundRejected(m.transactionId, m.validationError);
});
```

> "And that's the full integration: configure → connect → build a tiny tx with the roll as metadata → sign
> in your app → `postTransaction` → and the head confirms it back as `TxValid` at a new seq. Swap the dice
> metadata for a game move, a tip, a paywall unlock — same five steps. That's how you build micropayments
> on Hydra."

**Recap card to show on screen:**
| Step | Package API used | Your code |
|------|------------------|-----------|
| Configure | `HydraClientConfig`, `HydraHeadFacade` | host/port/TLS |
| Read state | `HydraHttpClient.getSnapshotUtxo()` | pick owned UTxO |
| Build | — | tx body + dice metadata |
| Sign | — (your `HydraSigner`) | Blake2b hash + Ed25519 witness |
| Submit | `HydraHttpClient.postTransaction()` *(or `facade.sendNewTx`)* | envelope |
| Confirm | `facade.messages` → `HydraTxValid` | update the UI row |

---

## 7. Close the head — back to L1  (~1.5 min)

Back in the **Hydra** tab:
1. **Close** → head enters the contestation period.
2. (Optional) **Contest** with a newer snapshot; mention **SafeClose** only closes if the latest snapshot is confirmed.
3. **Fanout** → the final UTxO set is distributed back to L1.

> "`Close` starts the contestation window, `Contest` lets a party submit a newer confirmed snapshot, and
> `Fanout` settles the agreed final balances back on-chain. That's the whole lifecycle: open → transact →
> close → fan out."

---

## 8. Production notes  (~1.5 min)

On screen: the README **Security considerations** section.

> "Three things before you ship a real app:"
- **TLS:** the default config is plaintext `ws://`/`http://` for localhost convenience — set `secure: true` (or pass a `wss://` URL) in production so addresses and transactions aren't on the wire in the clear.
- **Encrypt persisted state:** if you implement `HydraStateStore` on disk, encrypt it — it can reference UTxO data. The default in-memory store isn't persisted.
- **Keys stay in your app:** signing is your `HydraSigner` against a wallet / secure enclave — the package never holds keys.

> "And releases are automated: tag `hydra_client-vX.Y.Z` and GitHub Actions publishes to pub.dev via OIDC —
> no tokens in the repo."

---

## 9. Outro / CTA  (~0.5 min)

> "That's `hydra_client`: from `pub add` to a working Hydra micropayments app on mobile. Grab it on pub.dev,
> the source and this demo are on GitHub, and the full docs are on the site. If you build something with it,
> open an issue and tell us. Thanks for watching."

On screen, end card with:
- pub.dev/packages/hydra_client
- github.com/dextrlabs-dev/hydra-mobile-sdk
- dextrlabs-dev.github.io/hydra-mobile-sdk

---

## Appendix — Segment 6 integration code (Dice / Snake → L2)

Show these three snippets in order. The story: **build+sign a tx (your app) → submit it → react to the
typed `TxValid` at a new seq.** Submission and the result event are decoupled — you submit a tx, and the
confirmation arrives asynchronously on the `messages` stream.

**(1) Wire up once — listen and correlate results back to a move.**
```dart
final hydra = HydraHeadFacade(config: config);

// Remember which move each tx id belongs to, so we can update that UI row on TxValid.
final pending = <String, int>{}; // txId -> roundIndex

hydra.messages.listen((msg) {
  switch (msg) {
    case HydraTxValid():                       // L2 tx accepted into the head
      final round = pending.remove(msg.transactionId);
      print('round $round settled on L2 @ seq ${msg.seq}');
    case HydraTxInvalid():                      // rejected — surface to the user
      pending.remove(msg.transactionId);
      print('rejected: ${msg.validationError}');
    case HydraServerSnapshot():                 // new confirmed head balance
      print('snapshot @ seq ${msg.seq}');
    default:
  }
});

await hydra.connect();
```

**(2) Make a move — build + sign in your app, then submit.** Two equivalent paths; pick one.
```dart
// Your app builds and SIGNS the tx (keys never go into the package).
// In the demo this is DiceHydraSubmit / SnakeHydraSubmit using catalyst_cardano_serialization.
final Map<String, dynamic> signedTx = {
  'type': 'Tx ConwayEra',
  'description': '',
  'cborHex': signedTxCborHex,   // <- produced by your HydraSigner / wallet
  // 'txId': '<hex>',           // optional; lets you correlate before TxValid arrives
};

// Path A — over the WebSocket as a NewTx client input:
hydra.sendNewTx(signedTx);

// Path B — over REST (what the demo uses), same envelope:
final res = await hydra.hydraHttp.postTransaction(signedTx);
// res.statusCode 200/202 => accepted into the mempool; TxValid still arrives on messages.
```

**(3) The real demo call — one line per dice roll.** Point at `lib/services/dice_hydra_submit.dart`:
it loads `/snapshot/utxo`, finds the UTxO this mnemonic owns, attaches dice metadata, **signs**, and
`POST`s `/transaction`.
```dart
final txId = await DiceHydraSubmit.submitDiceRoll(
  config: config,
  mnemonic: devnetMnemonic,   // devnet only — magic 42
  diceValue: roll,            // 1..6
  roundIndex: round,
  ttlSlot: ttl,
);
pending[txId] = round;        // correlate; UI flips to "settled" when TxValid(seq) lands
```

> Talking point: "Every roll is a real Cardano transaction — built and **signed in the app**, submitted to
> the head, validated by the node, and confirmed back as `TxValid` at a new `seq`, instantly and with no
> L1 fee. The package handles submit + the typed result stream; the package never sees your keys."

---

## Appendix — one-screen command cheat sheet

```bash
# devnet
cd hydra/demo && ./prepare-devnet.sh && docker compose up -d cardano-node \
  && ./seed-devnet.sh && docker compose up -d hydra-node-1 hydra-node-2 hydra-node-3

# package
flutter pub add hydra_client

# demo app
cd example/hydra_demo && flutter pub get && flutter run
#   Hydra tab: host 127.0.0.1 / port 4001 → Connect → Send Init → Commit (L1) → Open
#   Dice / Snake tabs: play → L2 NewTx → TxValid
#   Hydra tab: Close → (Contest) → Fanout
```

## Appendix — if something breaks on camera
- App won't connect → confirm `docker compose ps` shows hydra-node-1 healthy on 4001; check host/port.
- Commit fails → re-load L1 UTxOs from the mnemonic; the devnet must be seeded (`seed-devnet.sh`).
- Head stuck → tear down and re-up the three hydra nodes; re-init.
- Keep a pre-recorded clip of the happy path as a fallback B-roll.
</content>

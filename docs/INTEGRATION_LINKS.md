# hydra_client integration — code map (Dice & Snake)

Direct links to where the **[`hydra_client`](https://pub.dev/packages/hydra_client)** package is used in the
demo app, for the workshop walkthrough. Repo: <https://github.com/dextrlabs-dev/hydra-mobile-sdk> (branch `main`).

**One-liner:** the dice/snake services build + sign a tiny L2 transaction, call
`HydraHttpClient.postTransaction(...)`, and the head confirms it back on `HydraHeadFacade.messages`
as a typed `HydraTxValid` at a new `seq`.

## The library being integrated
- [`packages/hydra_client/lib/hydra_client.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/packages/hydra_client/lib/hydra_client.dart) — public API surface the app imports

## Dice
- [`example/hydra_demo/lib/services/dice_hydra_submit.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/services/dice_hydra_submit.dart#L9-L116) — build → sign → submit
  - L9 `import 'package:hydra_client/hydra_client.dart';`
  - L34 `HydraHttpClient(config: config)` → `getSnapshotUtxo()`
  - L110 `http.postTransaction({...})` → submit signed L2 dice tx
- [`example/hydra_demo/lib/dice_game_tab.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/dice_game_tab.dart) — UI button → `DiceHydraSubmit.submitDiceRoll(...)`

## Snake
- [`example/hydra_demo/lib/services/snake_hydra_submit.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/services/snake_hydra_submit.dart#L9-L110) — same shape (L9 import, L32 `HydraHttpClient`, L104 `postTransaction`)
- [`example/hydra_demo/lib/snake_game_tab.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/snake_game_tab.dart) — game loop → `SnakeHydraSubmit.submitSnakeEvent(...)` (on fruit)

## Connection / live message stream (high-level facade)
- [`example/hydra_demo/lib/connection_tab.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/connection_tab.dart) — `HydraHeadFacade(...)`, `facade.messages.listen(...)`, `facade.connect(...)` (~L253–L297)
- [`example/hydra_demo/lib/services/l2_tx_submit_helpers.dart`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/example/hydra_demo/lib/services/l2_tx_submit_helpers.dart) — `findOwnedUnspent`, `decodeL2TransactionResponse`

---

**Note:** line anchors are exact for the `services/*.dart` files (unchanged on `main`). For
`connection_tab.dart` / `snake_game_tab.dart` they may be off by a few lines — the workshop fixes
(web int fix, board sizing, default `:4021`, hidden commit) are local and not yet pushed to `main`.
</content>

# hydra_client

[![pub package](https://img.shields.io/pub/v/hydra_client.svg)](https://pub.dev/packages/hydra_client)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/packages/hydra_client/LICENSE)

A Flutter-friendly Dart client for **[Cardano Hydra](https://hydra.family/)** `hydra-node` — the HTTP +
WebSocket client API. It gives you typed inbound messages, a reconnecting WebSocket session, optional
sequence-number sync across restarts, and a high-level head facade. Signing and key custody are left to
your app (via the `HydraSigner` interface), so the package never touches private keys.

Pure Dart with no Flutter dependency — works on Android, iOS, web, and desktop via platform-conditional
WebSocket transport.

## Install

```bash
flutter pub add hydra_client   # or: dart pub add hydra_client
```

```yaml
dependencies:
  hydra_client: ^1.0.0
```

## Quick start

```dart
import 'package:hydra_client/hydra_client.dart';

Future<void> main() async {
  // Point at your hydra-node client API. Use secure: true for wss/https in production.
  final config = HydraClientConfig(host: '127.0.0.1', port: 4001, secure: false);

  final hydra = HydraHeadFacade(config: config);

  // Typed, seq-deduped server messages (Greetings first on connect).
  final sub = hydra.messages.listen((msg) {
    switch (msg) {
      case HydraGreetings():
        print('connected; head status in payload: ${msg.json['headStatus']}');
      case HydraTxValid():
        print('tx valid @ seq ${msg.seq}');
      case HydraServerSnapshot():
        print('snapshot @ seq ${msg.seq}');
      default:
        print('message: ${msg.runtimeType}');
    }
  });

  // Watch transport state (connecting / connected / reconnecting / disconnected).
  hydra.connectionState.listen((s) => print('state: $s'));

  await hydra.connect();

  // Drive the head lifecycle / submit L2 transactions:
  hydra.sendInit();
  // hydra.sendNewTx({'cborHex': '...', 'type': 'Tx ConwayEra', 'description': ''});

  // ... when done:
  await sub.cancel();
  await hydra.dispose();
}
```

For lower-level control, use `HydraSession` (single socket) or `ReconnectingHydraSession` directly, and
`HydraHttpClient` for the REST endpoints (snapshots, head state, L1 commits).

## Security considerations

- **Use TLS in production.** The default `HydraClientConfig(secure: false)` produces plaintext `ws://` /
  `http://`, which is convenient for a local devnet but exposes addresses, UTxOs, and transactions on the
  wire. Set `secure: true` (→ `wss` / `https`), or pass a `wss://` / `https://` URL to
  `HydraClientConfig.fromUiFields`, for anything beyond `localhost`.
- **Proxy bypass on native platforms.** On `dart:io` targets the WebSocket transport sets
  `findProxy = DIRECT`, so it ignores any system HTTP proxy (this avoids emulator localhost-proxy
  failures). Ensure your `hydra-node` is reachable directly and secured by TLS.
- **Encrypt persisted state.** If you implement `HydraStateStore` with on-disk persistence
  (e.g. `shared_preferences`), the stored seq / snapshot hints may reference UTxO data — encrypt them at
  rest. The default `InMemoryHydraStateStore` is ephemeral and not persisted.

## Links

- **Documentation site:** <https://dextrlabs-dev.github.io/hydra-mobile-sdk/>
- **Source & issues:** <https://github.com/dextrlabs-dev/hydra-mobile-sdk>
- **Example app** (Flutter micropayments demo, Android/iOS/Linux): [`example/hydra_demo`](https://github.com/dextrlabs-dev/hydra-mobile-sdk/tree/main/example/hydra_demo)
- **Changelog:** [CHANGELOG.md](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/packages/hydra_client/CHANGELOG.md)
- **Hydra API reference:** <https://hydra.family/head-protocol/unstable/api-reference>

## License

MIT — see [LICENSE](https://github.com/dextrlabs-dev/hydra-mobile-sdk/blob/main/packages/hydra_client/LICENSE).
</content>
</invoke>

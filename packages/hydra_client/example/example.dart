// Minimal hydra_client usage: connect to a hydra-node, print typed messages,
// drive the head lifecycle, then dispose.
//
// Run against a local Hydra devnet (see https://hydra.family/head-protocol/docs/getting-started),
// whose node 1 client API defaults to 127.0.0.1:4001.
// ignore_for_file: avoid_print
import 'package:hydra_client/hydra_client.dart';

Future<void> main() async {
  // Use secure: true (wss/https) for anything beyond a local devnet.
  final config = HydraClientConfig(host: '127.0.0.1', port: 4001, secure: false);

  final hydra = HydraHeadFacade(config: config);

  final sub = hydra.messages.listen((msg) {
    switch (msg) {
      case HydraGreetings():
        print('connected; head status: ${msg.json['headStatus']}');
      case HydraTxValid():
        print('tx valid @ seq ${msg.seq}');
      case HydraServerSnapshot():
        print('snapshot @ seq ${msg.seq}');
      default:
        print('message: ${msg.runtimeType}');
    }
  });

  hydra.connectionState.listen((state) => print('state: $state'));

  await hydra.connect();

  // Open a new head (server validates the request).
  hydra.sendInit();

  // Submit an L2 transaction once the head is open:
  // hydra.sendNewTx({'cborHex': '...', 'type': 'Tx ConwayEra', 'description': ''});

  await sub.cancel();
  await hydra.dispose();
}

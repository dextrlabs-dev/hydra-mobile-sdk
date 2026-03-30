import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_demo/services/ogmios_aux_data_fetcher.dart';

void main() {
  test(
    'httpBaseUrlToWebSocketUrl maps http to ws',
    () {
      expect(
        OgmiosAuxDataFetcher.httpBaseUrlToWebSocketUrl('http://127.0.0.1:1337'),
        'ws://127.0.0.1:1337',
      );
      expect(
        OgmiosAuxDataFetcher.httpBaseUrlToWebSocketUrl('https://x.example:443/'),
        'wss://x.example:443',
      );
    },
  );

  test(
    'chain sync finds an early devnet tx (requires Ogmios on 127.0.0.1:1337)',
    () async {
      final r = await OgmiosAuxDataFetcher.fetchAuxiliaryDataForTransaction(
        transactionId:
            '99dd329345631c2e75cf7f195cc6f3234f4d5e30b410fe60854709dbd8478839',
        httpBaseUrl: 'http://127.0.0.1:1337',
        maxForwardBlocks: 400,
      );
      expect(r.found, true);
      expect(r.transactionJson, isNotNull);
    },
    skip: true,
  );
}

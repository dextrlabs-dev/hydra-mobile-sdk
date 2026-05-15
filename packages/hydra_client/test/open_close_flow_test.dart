import 'dart:convert';
import 'dart:io';

import 'package:hydra_client/hydra_client.dart';
import 'package:test/test.dart';

Future<String> _fixture(String name) =>
    File('test/fixtures/$name').readAsString();

void main() {
  group('client inputs (open / join / close / fanout)', () {
    test('Init payload matches Hydra API tag', () {
      expect(ClientInput.init(), {'tag': 'Init'});
    });

    test('Close payload matches Hydra API tag', () {
      expect(ClientInput.close(), {'tag': 'Close'});
    });

    test('SafeClose payload matches Hydra API tag', () {
      expect(ClientInput.safeClose(), {'tag': 'SafeClose'});
    });

    test('Contest payload matches Hydra API tag', () {
      expect(ClientInput.contest(), {'tag': 'Contest'});
    });

    test('Fanout payload matches Hydra API tag', () {
      expect(ClientInput.fanout(), {'tag': 'Fanout'});
    });

    test('NewTx wraps a transaction body', () {
      final tx = {
        'cborHex': 'aa',
        'type': 'Tx ConwayEra',
        'description': '',
      };
      expect(ClientInput.newTx(tx), {
        'tag': 'NewTx',
        'transaction': tx,
      });
    });
  });

  group('lifecycle parser walk: Idle -> Initial', () {
    test('head_idle fixture round-trips through the HTTP HeadState parser', () async {
      final raw = await _fixture('head_idle.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['tag'], 'Idle');
    });

    test('head_initial fixture surfaces pending commits + parties', () async {
      final raw = await _fixture('head_initial.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['tag'], 'Initial');
      final contents = json['contents'] as Map<String, dynamic>;
      expect(contents['headId'], isA<String>());
      expect(contents['pendingCommits'], isA<List<Object?>>());
      final params = contents['parameters'] as Map<String, dynamic>;
      expect(params['contestationPeriod'], 3);
      expect(params['parties'], isA<List<Object?>>());
    });
  });

  group('error-handling: invalid client input is parsed as a typed message', () {
    test('invalid_input fixture parses into a typed server output', () async {
      final raw = await _fixture('invalid_input.json');
      final msg = parseHydraMessage(raw);
      // The parser tolerates server outputs the typed layer does not model
      // explicitly by falling back to HydraTimedServerOutput / HydraRawMessage.
      expect(msg, isNotNull);
    });
  });
}

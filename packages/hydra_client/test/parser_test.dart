import 'dart:convert';
import 'dart:io';

import 'package:hydra_client/hydra_client.dart';
import 'package:test/test.dart';

Future<String> _fixture(String name) =>
    File('test/fixtures/$name').readAsString();

void main() {
  test('parses Greetings fixture', () async {
    final msg = parseHydraMessage(await _fixture('greetings.json'));
    expect(msg, isA<HydraGreetings>());
    final g = msg as HydraGreetings;
    expect(g.headStatus, 'Idle');
    expect(g.hydraNodeVersion, '2.0.0');
    expect(g.me, isA<Map<Object?, Object?>>());
  });

  test('parses timed NetworkConnected', () async {
    final msg = parseHydraMessage(await _fixture('network_connected.json'));
    expect(msg, isA<HydraTimedServerOutput>());
    final t = msg as HydraTimedServerOutput;
    expect(t.tag, 'NetworkConnected');
    expect(t.seq, 1);
    expect(t.timestamp, isNotNull);
  });

  test('parses TxValid', () async {
    final msg = parseHydraMessage(await _fixture('tx_valid.json'));
    expect(msg, isA<HydraTxValid>());
    final v = msg as HydraTxValid;
    expect(v.seq, 42);
    expect(v.transactionId, 'deadbeef');
  });

  test('parses TxInvalid', () async {
    final msg = parseHydraMessage(await _fixture('tx_invalid.json'));
    expect(msg, isA<HydraTxInvalid>());
    final inv = msg as HydraTxInvalid;
    expect(inv.seq, 43);
    expect(inv.validationError, 'ValidationError');
  });

  test('parses Snapshot timed output', () async {
    final msg = parseHydraMessage(await _fixture('snapshot_timed.json'));
    expect(msg, isA<HydraServerSnapshot>());
    final s = msg as HydraServerSnapshot;
    expect(s.seq, 10);
    expect(s.json['snapshot'], isA<Map<String, dynamic>>());
  });

  test('parses InvalidInput', () async {
    final msg = parseHydraMessage(await _fixture('invalid_input.json'));
    expect(msg, isA<HydraInvalidInput>());
    final inv = msg as HydraInvalidInput;
    expect(inv.reason, contains('not enough input'));
    expect(inv.input, 'not-json');
  });

  test('Greetings without tag (legacy shape)', () {
    final raw = jsonEncode({
      'me': {'vkey': 'aa'},
      'headStatus': 'Open',
      'hydraNodeVersion': '1.0.0',
    });
    final msg = parseHydraMessage(raw);
    expect(msg, isA<HydraGreetings>());
  });

  test('ClientInput maps include expected tags', () {
    expect(ClientInput.init(), {'tag': 'Init'});
    expect(ClientInput.close(), {'tag': 'Close'});
    expect(ClientInput.safeClose(), {'tag': 'SafeClose'});
    expect(ClientInput.contest(), {'tag': 'Contest'});
    expect(ClientInput.fanout(), {'tag': 'Fanout'});
    expect(
      ClientInput.newTx({
        'cborHex': 'ab',
        'type': 'Tx ConwayEra',
        'description': '',
      }),
      {
        'tag': 'NewTx',
        'transaction': {
          'cborHex': 'ab',
          'type': 'Tx ConwayEra',
          'description': '',
        },
      },
    );
  });

  test('HydraClientConfig builds WebSocket URI with query params', () {
    const c = HydraClientConfig(
      host: '127.0.0.1',
      port: 4001,
      history: false,
      snapshotUtxo: false,
      addressFilter: 'addr_test1qp',
    );
    expect(
      c.webSocketUri.toString(),
      'ws://127.0.0.1:4001/?history=no&snapshot-utxo=no&address=addr_test1qp',
    );
    expect(c.httpUri('/commit').toString(), 'http://127.0.0.1:4001/commit');
  });

  test('HydraClientConfig.fromUiFields parses URL and host:port', () {
    final a = HydraClientConfig.fromUiFields(
      'ws://139.59.94.155:4001',
      '9999',
      history: true,
    );
    expect(a.host, '139.59.94.155');
    expect(a.port, 4001);
    expect(a.secure, false);

    final b = HydraClientConfig.fromUiFields('139.59.94.155:4001', '4001');
    expect(b.host, '139.59.94.155');
    expect(b.port, 4001);
  });
}

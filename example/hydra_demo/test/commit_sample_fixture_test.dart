import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_demo/fixtures/commit_sample_fixture.dart';

void main() {
  test('sample commit UTxO JSON is a single txHash#ix object map', () {
    final decoded = jsonDecode(kSampleCommitUtxoJson.trim());
    expect(decoded, isA<Map<String, dynamic>>());
    final m = decoded as Map<String, dynamic>;
    expect(m.length, 1);
    expect(m.keys.single, contains('#'));
    final out = m.values.single as Map<String, dynamic>;
    expect(out['address'], isNotNull);
    expect(out['value'], isA<Map>());
    expect((out['value'] as Map)['lovelace'], 50000000);
  });

  test('sample mnemonic is 12 words', () {
    expect(kSampleBip39Mnemonic.split(RegExp(r'\s+')), hasLength(12));
  });
}

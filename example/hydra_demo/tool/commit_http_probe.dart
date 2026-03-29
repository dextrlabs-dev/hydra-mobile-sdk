// Draft commit: POST /commit with sample fixture (no signing).
// Also parses returned CBOR with the same normalizer as the app (no Rust).
// Full sign + POST /cardano-transaction → use Android app (Commit tile).
//
// From example/hydra_demo: dart run tool/commit_http_probe.dart
import 'dart:convert';
import 'dart:io';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:cbor/cbor.dart' as cbor;
import 'package:convert/convert.dart';
import 'package:hydra_client/hydra_client.dart';

import 'package:hydra_demo/fixtures/commit_sample_fixture.dart';
import 'package:hydra_demo/services/hydra_tx_cbor_normalize.dart';

Future<void> main() async {
  final config = HydraClientConfig(
    host: '139.59.94.155',
    port: 4001,
    history: true,
  );
  final utxo =
      jsonDecode(kSampleCommitUtxoJson.trim()) as Map<String, dynamic>;

  final http = HydraHttpClient(config: config);
  try {
    stderr.writeln('POST ${config.httpUri('/commit')}');
    final res = await http.postCommit({'utxoToCommit': utxo});
    stdout.writeln('status: ${res.statusCode}');
    if (res.statusCode != 200) {
      stdout.writeln(res.body);
      exit(1);
    }
    final env = jsonDecode(res.body) as Map<String, dynamic>;
    final cborHex = env['cborHex'] as String?;
    if (cborHex == null || cborHex.isEmpty) {
      stderr.writeln('No cborHex in body');
      exit(1);
    }
    final raw = cbor.cbor.decode(hex.decode(cborHex));
    final tx = Transaction.fromCbor(normalizeHydraCommitTransactionCbor(raw));
    stderr.writeln(
      'Parsed draft Tx: ${tx.body.inputs.length} inputs, '
      '${tx.body.outputs.length} outputs, '
      '${tx.witnessSet.vkeyWitnesses.length} vkey witnesses',
    );
    stdout.writeln(jsonEncode(env));
    exit(0);
  } finally {
    http.close();
  }
}

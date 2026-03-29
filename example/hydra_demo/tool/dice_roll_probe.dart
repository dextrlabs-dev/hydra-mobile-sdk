// One-shot dice L2 tx (same path as Dice tab): GET /snapshot/utxo, build tx,
// POST /transaction. Requires an open head with a UTxO for the sample mnemonic.
//
// From example/hydra_demo:
//   dart run tool/dice_roll_probe.dart [host] [port]
// Defaults: 127.0.0.1 4001 (local hydra-node client API).
//
// Native catalyst_key_derivation: use Android emulator/device if `dart run` fails on Windows.
import 'dart:convert';
import 'dart:io';

import 'package:catalyst_key_derivation/catalyst_key_derivation.dart';
import 'package:hydra_client/hydra_client.dart';

import 'package:hydra_demo/fixtures/commit_sample_fixture.dart';
import 'package:hydra_demo/services/dice_hydra_submit.dart';

int? _slotFromHeadJson(Object? j) {
  if (j is Map) {
    final cs = j['currentSlot'];
    if (cs is int) return cs;
    if (cs is num) return cs.toInt();
    if (cs is Map) {
      final inner = cs['slot'];
      if (inner is int) return inner;
      if (inner is num) return inner.toInt();
    }
    for (final v in j.values) {
      final s = _slotFromHeadJson(v);
      if (s != null) return s;
    }
  } else if (j is List) {
    for (final v in j) {
      final s = _slotFromHeadJson(v);
      if (s != null) return s;
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  await CatalystKeyDerivation.init();

  final host = args.isNotEmpty ? args[0] : '127.0.0.1';
  final port = args.length > 1 ? (int.tryParse(args[1]) ?? 4001) : 4001;
  final config = HydraClientConfig(host: host, port: port, history: true);

  final http = HydraHttpClient(config: config);
  int ttlSlot;
  try {
    final h = await http.getHeadState();
    if (h.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(h.bodyBytes));
      final slot = _slotFromHeadJson(decoded);
      if (slot != null) {
        ttlSlot = slot + 50000;
        stderr.writeln('GET /head → currentSlot≈$slot, using ttl=$ttlSlot');
      } else {
        ttlSlot = 100000000;
        stderr.writeln('No currentSlot in /head JSON; using ttl=$ttlSlot');
      }
    } else {
      ttlSlot = 100000000;
      stderr.writeln('GET /head ${h.statusCode}; using ttl=$ttlSlot');
    }
  } finally {
    http.close();
  }

  stderr.writeln(
    'POST /transaction (mnemonic=kSampleBip39) → ${config.httpUri('/transaction')}',
  );
  try {
    final body = await DiceHydraSubmit.submitDiceRoll(
      config: config,
      mnemonic: kSampleBip39Mnemonic,
      diceValue: 3,
      roundIndex: 0,
      ttlSlot: ttlSlot,
    );
    stdout.writeln(body);
    exit(0);
  } catch (e, st) {
    stderr.writeln('$e');
    stderr.writeln(st);
    exit(1);
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:catalyst_key_derivation/catalyst_key_derivation.dart' as kd;
import 'package:cbor/cbor.dart' as cbor;
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hydra_client/hydra_client.dart';

import 'l2_tx_submit_helpers.dart';

class SnakeHydraSubmit {
  SnakeHydraSubmit._();

  static const _paymentPath = "m/1852'/1815'/0'/0/0";

  static Future<String> submitSnakeEvent({
    required HydraClientConfig config,
    required String mnemonic,
    required int ttlSlot,
    required String sessionId,
    required int step,
    required String eventType, // move | fruit | game_over
    required int x,
    required int y,
    required String dir,
    required int score,
    required int length,
    String? reason,
  }) async {
    final http = HydraHttpClient(config: config);
    try {
      final utxoRes = await http.getSnapshotUtxo();
      if (utxoRes.statusCode != 200) {
        throw StateError('GET /snapshot/utxo failed (${utxoRes.statusCode})');
      }
      final utxoMap = jsonDecode(utf8.decode(utxoRes.bodyBytes)) as Map<String, dynamic>;
      if (utxoMap.isEmpty) {
        throw StateError('Empty UTxO set in head. Commit funds first.');
      }

      const derivation = kd.CatalystKeyDerivation();
      final master = await derivation.deriveMasterKey(mnemonic: mnemonic.trim());
      final paymentSk = await master.derivePrivateKey(path: _paymentPath);
      final paymentVk = await paymentSk.derivePublicKey();
      final paymentPub = paymentVk.toPublicKey();
      final paymentKeyHash = Ed25519PublicKeyHash.fromPublicKey(paymentPub);

      final match = findOwnedUnspent(utxoMap, paymentKeyHash);
      if (match == null) {
        throw StateError('No UTxO matches this mnemonic at $_paymentPath.');
      }

      final meta = AuxiliaryData(
        map: {
          cbor.CborSmallInt(1): cbor.CborString('hydra_demo_snake'),
          cbor.CborSmallInt(2): cbor.CborString(sessionId),
          cbor.CborSmallInt(3): cbor.CborSmallInt(step),
          cbor.CborSmallInt(4): cbor.CborString(eventType),
          cbor.CborSmallInt(5): cbor.CborSmallInt(x),
          cbor.CborSmallInt(6): cbor.CborSmallInt(y),
          cbor.CborSmallInt(7): cbor.CborString(dir),
          cbor.CborSmallInt(8): cbor.CborSmallInt(score),
          cbor.CborSmallInt(9): cbor.CborSmallInt(length),
          if (reason != null) cbor.CborSmallInt(10): cbor.CborString(reason),
          cbor.CborSmallInt(11): cbor.CborSmallInt(DateTime.now().millisecondsSinceEpoch),
        },
      );

      const txConfig = TransactionBuilderConfig(
        feeAlgo: TieredFee(constant: 0, coefficient: 0, refScriptByteCost: 0),
        maxTxSize: 16384,
        maxValueSize: 5000,
        coinsPerUtxoByte: Coin(4310),
      );

      final builder = TransactionBuilder(
        config: txConfig,
        inputs: {match.unspent},
        ttl: SlotBigNum(ttlSlot),
        auxiliaryData: meta,
        networkId: NetworkId.testnet,
      );

      final body = builder.withChangeAddressIfNeeded(match.changeAddress).buildBody();

      final bodyBytes = Uint8List.fromList(cbor.cbor.encode(body.toCbor()));
      final digest = await Blake2b(hashLengthInBytes: 32).hash(bodyBytes);
      final sig = await paymentSk.sign(digest.bytes);
      final witness = VkeyWitness(
        vkey: paymentPub,
        signature: kd.Ed25519Signature.fromBytes(sig.bytes),
      );

      final signed = Transaction(
        body: body,
        isValid: true,
        witnessSet: TransactionWitnessSet(vkeyWitnesses: {witness}),
        auxiliaryData: meta,
      );

      final cborHex = hex.encode(cbor.cbor.encode(signed.toCbor()));
      final txRes = await http.postTransaction({
        'cborHex': cborHex,
        'type': 'Witnessed Tx ConwayEra',
        'description': 'hydra_demo snake $eventType sid=$sessionId step=$step',
      });

      return decodeL2TransactionResponse(txRes);
    } finally {
      http.close();
    }
  }
}


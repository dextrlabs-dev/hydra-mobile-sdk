import 'dart:convert';
import 'dart:typed_data';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:catalyst_key_derivation/catalyst_key_derivation.dart' as kd;
import 'package:cbor/cbor.dart' as cbor;
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hydra_client/hydra_client.dart';

/// Builds a small L2 transaction with dice metadata, signs with BIP39 path
/// `m/1852'/1815'/0'/0/0`, submits via Hydra `POST /transaction`.
///
/// **Demo only.** Your mnemonic must control a UTxO already present in
/// `/snapshot/utxo` (open head + commit).
class DiceHydraSubmit {
  DiceHydraSubmit._();

  static const _paymentPath = "m/1852'/1815'/0'/0/0";

  static Future<String> submitDiceRoll({
    required HydraClientConfig config,
    required String mnemonic,
    required int diceValue,
    required int roundIndex,
    required int ttlSlot,
  }) async {
    if (diceValue < 1 || diceValue > 6) {
      throw ArgumentError.value(diceValue, 'diceValue', 'expected 1..6');
    }

    final http = HydraHttpClient(config: config);
    try {
      final utxoRes = await http.getSnapshotUtxo();
      if (utxoRes.statusCode != 200) {
        throw StateError(
          'GET /snapshot/utxo failed (${utxoRes.statusCode}). '
          'Open a head and commit funds first.',
        );
      }
      final utxoMap = jsonDecode(utf8.decode(utxoRes.bodyBytes)) as Map<String, dynamic>;
      if (utxoMap.isEmpty) {
        throw StateError('Empty UTxO set in head.');
      }

      const derivation = kd.CatalystKeyDerivation();
      final master = await derivation.deriveMasterKey(mnemonic: mnemonic.trim());
      final paymentSk = await master.derivePrivateKey(path: _paymentPath);
      final paymentVk = await paymentSk.derivePublicKey();
      final paymentPub = paymentVk.toPublicKey();
      final paymentKeyHash = Ed25519PublicKeyHash.fromPublicKey(paymentPub);

      final match = _findOwnedUnspent(utxoMap, paymentKeyHash);
      if (match == null) {
        throw StateError(
          'No UTxO in /snapshot/utxo matches this mnemonic at $_paymentPath.',
        );
      }

      final meta = AuxiliaryData(
        map: {
          cbor.CborSmallInt(1): cbor.CborString('hydra_demo_dice'),
          cbor.CborSmallInt(2): cbor.CborSmallInt(diceValue),
          cbor.CborSmallInt(3): cbor.CborSmallInt(roundIndex),
        },
      );

      const txConfig = TransactionBuilderConfig(
        feeAlgo: TieredFee(
          constant: 0,
          coefficient: 0,
          refScriptByteCost: 0,
        ),
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
        'description': 'hydra_demo dice r$roundIndex=$diceValue',
      });

      if (txRes.statusCode != 200) {
        throw StateError('POST /transaction ${txRes.statusCode}: ${txRes.body}');
      }
      return utf8.decode(txRes.bodyBytes);
    } finally {
      http.close();
    }
  }

  static _OwnedMatch? _findOwnedUnspent(
    Map<String, dynamic> utxoMap,
    Ed25519PublicKeyHash paymentKeyHash,
  ) {
    for (final e in utxoMap.entries) {
      final key = e.key;
      final out = e.value as Map<String, dynamic>;
      final addrStr = out['address'] as String?;
      if (addrStr == null) continue;
      final addr = ShelleyAddress.fromBech32(addrStr);
      if (addr.publicKeyHash != paymentKeyHash) continue;

      final parts = key.split('#');
      if (parts.length != 2) continue;
      final txId = parts[0];
      final ix = int.parse(parts[1]);
      final value = out['value'] as Map<String, dynamic>?;
      final lovelace = (value?['lovelace'] as num?)?.toInt() ?? 0;
      if (lovelace <= 0) continue;

      final unspent = TransactionUnspentOutput(
        input: TransactionInput(
          transactionId: TransactionHash.fromHex(txId),
          index: ix,
        ),
        output: TransactionOutput(
          address: addr,
          amount: Balance(coin: Coin(lovelace)),
        ),
      );
      return _OwnedMatch(changeAddress: addr, unspent: unspent);
    }
    return null;
  }
}

class _OwnedMatch {
  _OwnedMatch({required this.changeAddress, required this.unspent});

  final ShelleyAddress changeAddress;
  final TransactionUnspentOutput unspent;
}

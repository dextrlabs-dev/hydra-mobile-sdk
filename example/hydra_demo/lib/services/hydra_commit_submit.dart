import 'dart:convert';
import 'dart:typed_data';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:catalyst_key_derivation/catalyst_key_derivation.dart' as kd;
import 'package:cbor/cbor.dart' as cbor;
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hydra_client/hydra_client.dart';

/// Drafts a Hydra commit tx (POST /commit), signs with payment key at
/// [paymentPath], submits to L1 (POST /cardano-transaction).
///
/// [utxoToCommit] is Hydra UTxO JSON (same shape as cardano-cli query utxo).
class HydraCommitSubmit {
  HydraCommitSubmit._();

  static const defaultPaymentPath = "m/1852'/1815'/0'/0/0";

  static Future<String> draftSignAndSubmitL1Commit({
    required HydraClientConfig config,
    required String mnemonic,
    required Map<String, dynamic> utxoToCommit,
    String paymentPath = defaultPaymentPath,
  }) async {
    if (utxoToCommit.isEmpty) {
      throw ArgumentError('utxoToCommit must not be empty');
    }

    const derivation = kd.CatalystKeyDerivation();
    final master = await derivation.deriveMasterKey(mnemonic: mnemonic.trim());
    final paymentSk = await master.derivePrivateKey(path: paymentPath);
    final paymentVk = await paymentSk.derivePublicKey();
    final paymentPub = paymentVk.toPublicKey();
    final paymentKeyHash = Ed25519PublicKeyHash.fromPublicKey(paymentPub);

    _assertUtxoOwnedByPaymentKey(utxoToCommit, paymentKeyHash, paymentPath);

    final http = HydraHttpClient(config: config);
    try {
      final draftRes = await http.postCommit({'utxoToCommit': utxoToCommit});
      if (draftRes.statusCode != 200) {
        throw StateError(
          'POST /commit ${draftRes.statusCode}: ${draftRes.body}',
        );
      }

      final envelope =
          jsonDecode(utf8.decode(draftRes.bodyBytes)) as Map<String, dynamic>;
      final cborHex = envelope['cborHex'] as String?;
      if (cborHex == null) {
        throw StateError('Commit response missing cborHex: ${draftRes.body}');
      }
      final txType = envelope['type'] as String? ?? 'Tx ConwayEra';
      final description = envelope['description'] as String? ?? '';

      final tx = Transaction.fromCbor(
        cbor.cbor.decode(hex.decode(cborHex)),
      );

      final bodyBytes = Uint8List.fromList(cbor.cbor.encode(tx.body.toCbor()));
      final digest = await Blake2b(hashLengthInBytes: 32).hash(bodyBytes);
      final sig = await paymentSk.sign(digest.bytes);
      final witness = VkeyWitness(
        vkey: paymentPub,
        signature: kd.Ed25519Signature.fromBytes(sig.bytes),
      );

      final merged = TransactionWitnessSet(
        vkeyWitnesses: {...tx.witnessSet.vkeyWitnesses, witness},
        nativeScripts: tx.witnessSet.nativeScripts,
        plutusV1Scripts: tx.witnessSet.plutusV1Scripts,
        redeemers: tx.witnessSet.redeemers,
        plutusV2Scripts: tx.witnessSet.plutusV2Scripts,
        plutusV3Scripts: tx.witnessSet.plutusV3Scripts,
      );

      final signed = Transaction(
        body: tx.body,
        isValid: tx.isValid,
        witnessSet: merged,
        auxiliaryData: tx.auxiliaryData,
      );

      final submitType = _witnessedEnvelopeType(txType);
      final body = <String, dynamic>{
        'cborHex': hex.encode(cbor.cbor.encode(signed.toCbor())),
        'type': submitType,
      };
      if (description.isNotEmpty) body['description'] = description;

      final submitRes = await http.postCardanoTransaction(body);

      if (submitRes.statusCode != 200) {
        throw StateError(
          'POST /cardano-transaction ${submitRes.statusCode}: ${submitRes.body}',
        );
      }
      return utf8.decode(submitRes.bodyBytes);
    } finally {
      http.close();
    }
  }

  static String _witnessedEnvelopeType(String serverType) {
    if (serverType.startsWith('Witnessed')) return serverType;
    if (serverType.startsWith('Tx ')) return 'Witnessed $serverType';
    return 'Witnessed Tx ConwayEra';
  }

  static void _assertUtxoOwnedByPaymentKey(
    Map<String, dynamic> utxo,
    Ed25519PublicKeyHash paymentKeyHash,
    String paymentPath,
  ) {
    for (final e in utxo.entries) {
      final out = e.value;
      if (out is! Map<String, dynamic>) {
        throw StateError('Invalid UTxO entry for ${e.key}');
      }
      final addrStr = out['address'] as String?;
      if (addrStr == null) {
        throw StateError('UTxO ${e.key} missing address');
      }
      final addr = ShelleyAddress.fromBech32(addrStr);
      if (addr.publicKeyHash != paymentKeyHash) {
        throw StateError(
          'UTxO ${e.key} address does not match mnemonic at $paymentPath',
        );
      }
    }
  }
}

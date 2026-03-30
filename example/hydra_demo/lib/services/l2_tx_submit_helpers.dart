import 'dart:convert';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:http/http.dart' as http;

class L2OwnedMatch {
  L2OwnedMatch({required this.changeAddress, required this.unspent});

  final ShelleyAddress changeAddress;
  final TransactionUnspentOutput unspent;
}

L2OwnedMatch? findOwnedUnspent(
  Map<String, dynamic> utxoMap,
  Ed25519PublicKeyHash paymentKeyHash,
) {
  for (final e in utxoMap.entries) {
    final key = e.key;
    final out = e.value;
    if (out is! Map) continue;
    final outMap = Map<String, dynamic>.from(out);
    final addrStr = outMap['address'] as String?;
    if (addrStr == null) continue;
    final addr = ShelleyAddress.fromBech32(addrStr);
    if (addr.publicKeyHash != paymentKeyHash) continue;

    final parts = key.split('#');
    if (parts.length != 2) continue;
    final txId = parts[0];
    final ix = int.tryParse(parts[1]);
    if (ix == null) continue;
    final value = outMap['value'] as Map<String, dynamic>?;
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
    return L2OwnedMatch(changeAddress: addr, unspent: unspent);
  }
  return null;
}

String decodeL2TransactionResponse(http.Response txRes) {
  final bodyStr = utf8.decode(txRes.bodyBytes);
  final code = txRes.statusCode;

  Map<String, dynamic>? json;
  try {
    final o = jsonDecode(bodyStr);
    if (o is Map<String, dynamic>) json = o;
  } catch (_) {}

  final tag = json?['tag'] as String?;
  if (tag == 'SubmitTxInvalid') {
    throw StateError('POST /transaction invalid: ${json?['validationError'] ?? bodyStr}');
  }
  if (tag == 'SubmitTxRejected') {
    throw StateError('POST /transaction rejected: ${json?['reason'] ?? bodyStr}');
  }
  final timeout = json?['timeout'];
  if (timeout != null) {
    throw StateError('POST /transaction: $timeout');
  }

  if (code != 200 && code != 202) {
    throw StateError('POST /transaction $code: $bodyStr');
  }
  return bodyStr;
}


import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ogmios-backed UTxO query (JSON-RPC).
///
/// Ogmios recommends querying UTxOs by output reference for large ledgers; for
/// the local Hydra demo devnet, the full UTxO is small enough that we can query
/// and filter client-side by address.
class OgmiosUtxoLoader {
  OgmiosUtxoLoader._();

  /// Default local Ogmios HTTP endpoint.
  static const defaultBaseUrl = 'http://127.0.0.1:1337';

  /// Query UTxO set from Ogmios and filter entries where `address == [address]`.
  ///
  /// Returns a map shaped like `cardano-cli query utxo --output-json`:
  /// `txHash#ix -> { address, value: { lovelace, ... }, ... }`.
  static Future<Map<String, dynamic>> queryUtxoByAddress({
    required String address,
    String baseUrl = defaultBaseUrl,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(baseUrl);
      final req = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'queryLedgerState/utxo',
        'params': <String, dynamic>{},
        'id': 'hydra_demo_utxo_${DateTime.now().millisecondsSinceEpoch}',
      };
      final res = await c.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(req),
      );
      if (res.statusCode != 200) {
        throw StateError('Ogmios HTTP ${res.statusCode}: ${res.body}');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw StateError('Unexpected Ogmios response: ${decoded.runtimeType}');
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['error'] != null) {
        throw StateError('Ogmios error: ${map['error']}');
      }

      final result = map['result'];
      return _normalizeAndFilter(result, address);
    } finally {
      if (client == null) {
        c.close();
      }
    }
  }

  static Map<String, dynamic> _normalizeAndFilter(
    dynamic result,
    String targetAddr,
  ) {
    // Observed shape (Ogmios nightly): list of { transaction: {id}, index, address, value: { ada: { lovelace } } }
    if (result is List) {
      final out = <String, dynamic>{};
      for (final item in result) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final addr = m['address'];
        if (addr != targetAddr) continue;
        final txId =
            (m['transaction'] is Map) ? (m['transaction'] as Map)['id'] : null;
        final ix = m['index'];
        if (txId is! String || ix is! int) continue;

        // Convert Ogmios value shape -> cardano-cli-ish value shape for Hydra /commit.
        final value = <String, dynamic>{};
        final v = m['value'];
        if (v is Map) {
          final ada = v['ada'];
          if (ada is Map) {
            final ll = ada['lovelace'];
            if (ll is int) value['lovelace'] = ll;
            if (ll is num) value['lovelace'] = ll.toInt();
          }
        }
        out['$txId#$ix'] = <String, dynamic>{
          'address': addr,
          'value': value,
          'datum': null,
          'datumhash': null,
          'inlineDatum': null,
          'inlineDatumRaw': null,
          'referenceScript': null,
        };
      }
      return out;
    }

    // Fallback: if Ogmios returns a map, attempt to filter it directly.
    if (result is Map) {
      final m = Map<String, dynamic>.from(result);
      final out = <String, dynamic>{};
      for (final e in m.entries) {
        final v = e.value;
        if (v is Map) {
          final vm = Map<String, dynamic>.from(v);
          if (vm['address'] == targetAddr) out[e.key] = vm;
        }
      }
      return out;
    }

    throw StateError(
        'Unexpected Ogmios utxo result shape: ${result.runtimeType}');
  }
}

import 'dart:convert';

/// Hydra `UTxO` JSON: map from `txHash#ix` to output objects.
typedef HydraUtxoMap = Map<String, dynamic>;

/// Decodes `GET /snapshot/utxo` (or any `UTxO` field) from JSON body.
HydraUtxoMap? parseHydraUtxoMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

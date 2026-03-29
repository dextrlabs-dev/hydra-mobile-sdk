/// Connection settings for a single `hydra-node` client API (`--api-port`).
class HydraClientConfig {
  const HydraClientConfig({
    required this.host,
    this.port = 4001,
    this.secure = false,
    this.history,
    this.snapshotUtxo,
    this.addressFilter,
  });

  final String host;
  final int port;

  /// Use `wss` / `https` when true.
  final bool secure;

  /// Maps to query `history=yes|no`. Omit to use server default.
  final bool? history;

  /// Maps to query `snapshot-utxo=yes|no`. Omit to use server default.
  final bool? snapshotUtxo;

  /// Maps to query `address=...` for filtered server outputs.
  final String? addressFilter;

  Uri get webSocketUri {
    final q = <String, String>{};
    if (history != null) {
      q['history'] = history! ? 'yes' : 'no';
    }
    if (snapshotUtxo != null) {
      q['snapshot-utxo'] = snapshotUtxo! ? 'yes' : 'no';
    }
    if (addressFilter != null && addressFilter!.isNotEmpty) {
      q['address'] = addressFilter!;
    }
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/',
      queryParameters: q.isEmpty ? null : q,
    );
  }

  Uri httpUri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: secure ? 'https' : 'http',
      host: host,
      port: port,
      path: p,
      queryParameters: query,
    );
  }
}

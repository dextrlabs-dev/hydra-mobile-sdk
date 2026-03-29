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

  /// Parses typical UI text fields (optional `ws://` / `http://` URL in [hostField],
  /// optional `host:port` for IPv4, optional `[ipv6]:port`).
  static HydraClientConfig fromUiFields(
    String hostField,
    String portField, {
    bool? history,
    bool? snapshotUtxo,
    String? addressFilter,
  }) {
    var host = hostField.trim();
    var port = int.tryParse(portField.trim());
    var secure = false;

    if (host.isEmpty) {
      throw FormatException('hydra-node host is empty');
    }

    if (host.contains('://')) {
      final uri = Uri.parse(host);
      secure = uri.isScheme('wss') || uri.isScheme('https');
      if (uri.host.isEmpty) {
        throw FormatException('Could not parse host from URL: $hostField');
      }
      host = uri.host;
      if (uri.hasPort) {
        port = uri.port;
      }
      port ??= int.tryParse(portField.trim()) ?? 4001;
    } else {
      port ??= int.tryParse(portField.trim()) ?? 4001;
      if (host.startsWith('[')) {
        final idx = host.indexOf(']:');
        if (idx != -1 && idx < host.length - 2) {
          final p = int.tryParse(host.substring(idx + 2));
          if (p != null) {
            port = p;
            host = host.substring(0, idx + 1);
          }
        }
      } else {
        final lastColon = host.lastIndexOf(':');
        if (lastColon > 0) {
          final tail = host.substring(lastColon + 1);
          if (RegExp(r'^\d{1,5}$').hasMatch(tail)) {
            final p = int.tryParse(tail);
            if (p != null && p <= 65535) {
              port = p;
              host = host.substring(0, lastColon);
            }
          }
        }
      }
    }

    if (host.isEmpty) {
      throw FormatException('hydra-node host is empty after parsing');
    }

    return HydraClientConfig(
      host: host,
      port: port,
      secure: secure,
      history: history,
      snapshotUtxo: snapshotUtxo,
      addressFilter: addressFilter,
    );
  }

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

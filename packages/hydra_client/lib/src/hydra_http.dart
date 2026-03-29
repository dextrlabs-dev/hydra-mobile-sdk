import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// HTTP endpoints exposed by `hydra-node` alongside WebSockets.
class HydraHttpClient {
  HydraHttpClient({required HydraClientConfig config, http.Client? httpClient})
      : _config = config,
        _client = httpClient ?? http.Client();

  final HydraClientConfig _config;
  final http.Client _client;

  Future<http.Response> postCommit(Object body) => _jsonPost('/commit', body);

  Future<http.Response> postCardanoTransaction(Object body) =>
      _jsonPost('/cardano-transaction', body);

  /// Submit a signed transaction to the open Hydra head (L2).
  ///
  /// Body is Hydra `Transaction` JSON (`cborHex`, `type`, `description`, optional `txId`).
  Future<http.Response> postTransaction(Object body) => _jsonPost('/transaction', body);

  Future<http.Response> getProtocolParameters() =>
      _client.get(_config.httpUri('/protocol-parameters'));

  Future<http.Response> getSnapshotUtxo() => _client.get(_config.httpUri('/snapshot/utxo'));

  Future<http.Response> getHeadState() => _client.get(_config.httpUri('/head'));

  Future<http.Response> getPendingCommits() => _client.get(_config.httpUri('/commits'));

  Future<http.Response> _jsonPost(String path, Object body) {
    final uri = _config.httpUri(path);
    return _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  void close() => _client.close();
}

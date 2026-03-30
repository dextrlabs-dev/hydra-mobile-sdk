import 'dart:convert';

import 'package:async/async.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Fetches **transaction auxiliary data** (a.k.a. tx metadata) via Ogmios **chain sync**
/// over WebSocket (`ws://…:1337`).
///
/// UTxO queries (`queryLedgerState/utxo`) do not include metadata; it lives on the
/// transaction body, so we walk blocks with `findIntersection` + `nextBlock` until
/// the transaction id matches.
class OgmiosAuxDataFetchResult {
  const OgmiosAuxDataFetchResult({
    required this.found,
    required this.transactionId,
    this.blockHeight,
    this.blockSlot,
    this.auxiliaryData,
    this.transactionJson,
    this.scannedForwardBlocks,
  });

  final bool found;
  final String transactionId;
  final int? blockHeight;
  final int? blockSlot;

  /// Present when the block includes an auxiliary data map for this tx (may be empty).
  final Map<String, dynamic>? auxiliaryData;

  /// Full transaction object from the block (Ogmios JSON), when found.
  final Map<String, dynamic>? transactionJson;

  final int? scannedForwardBlocks;
}

class OgmiosAuxDataFetcher {
  OgmiosAuxDataFetcher._();

  /// Maps `http://host:1337` → `ws://host:1337` (or `wss` / `443`).
  static String httpBaseUrlToWebSocketUrl(String httpBaseUrl) {
    final t = httpBaseUrl.trim();
    if (t.isEmpty) return 'ws://127.0.0.1:1337';
    final u = Uri.parse(t);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final port = u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80);
    final path = u.path.isEmpty || u.path == '/' ? '' : u.path;
    return Uri(scheme: scheme, host: u.host, port: port, path: path).toString();
  }

  static int? _tipHeightFromFindIntersection(Map<String, dynamic> msg) {
    final r = msg['result'];
    if (r is! Map<String, dynamic>) return null;
    final tip = r['tip'];
    if (tip is! Map<String, dynamic>) return null;
    final h = tip['height'];
    if (h is int) return h;
    if (h is num) return h.toInt();
    return null;
  }

  /// Scans forward from [intersectionPoints] (default `['origin']`) until [transactionId]
  /// is found or [maxForwardBlocks] forward blocks have been scanned.
  ///
  /// Uses pipelined `nextBlock` requests to reduce round-trip latency.
  static Future<OgmiosAuxDataFetchResult> fetchAuxiliaryDataForTransaction({
    required String transactionId,
    String httpBaseUrl = 'http://127.0.0.1:1337',
    List<dynamic>? intersectionPoints,
    void Function(int scannedForward, int? tipHeight)? onProgress,
    bool Function()? shouldCancel,
    int pipelineDepth = 80,
    int maxForwardBlocks = 2000000,
  }) async {
    final want = transactionId.trim().toLowerCase();
    if (want.isEmpty) {
      throw ArgumentError('transactionId is empty');
    }

    final wsUrl = httpBaseUrlToWebSocketUrl(httpBaseUrl);
    final uri = Uri.parse(wsUrl);
    final channel = WebSocketChannel.connect(uri);
    final queue = StreamQueue<dynamic>(channel.stream);
    var scanned = 0;
    int? tipHeight;
    var rpcSeq = 1;

    Future<Map<String, dynamic>> readOne() async {
      final raw = await queue.next;
      if (raw is! String) {
        throw StateError('Unexpected WS frame: ${raw.runtimeType}');
      }
      final d = jsonDecode(raw);
      if (d is! Map<String, dynamic>) {
        throw StateError('Unexpected JSON: ${d.runtimeType}');
      }
      return d;
    }

    void sendRpc(String method, Map<String, dynamic>? params, int id) {
      channel.sink.add(jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': method,
        if (params != null) 'params': params,
        'id': id,
      }));
    }

    try {
      sendRpc(
        'findIntersection',
        <String, dynamic>{
          'points': intersectionPoints ?? <dynamic>['origin'],
        },
        ++rpcSeq,
      );

      while (true) {
        if (shouldCancel?.call() == true) {
          throw StateError('Cancelled');
        }
        final msg = await readOne();
        if (msg.containsKey('id') && msg['id'] == 2) {
          if (msg['error'] != null) {
            throw StateError('findIntersection: ${msg['error']}');
          }
          tipHeight = _tipHeightFromFindIntersection(msg);
          break;
        }
      }

      var inFlight = 0;

      void pump() {
        while (inFlight < pipelineDepth && scanned + inFlight < maxForwardBlocks) {
          sendRpc('nextBlock', null, ++rpcSeq);
          inFlight++;
        }
      }

      pump();

      while (scanned < maxForwardBlocks) {
        if (shouldCancel?.call() == true) {
          throw StateError('Cancelled');
        }
        if (inFlight == 0) {
          pump();
          if (inFlight == 0) break;
        }

        final msg = await readOne();
        inFlight--;

        if (msg['error'] != null) {
          throw StateError('nextBlock: ${msg['error']}');
        }

        final result = msg['result'];
        if (result is! Map<String, dynamic>) {
          pump();
          continue;
        }

        final dir = result['direction'];
        if (dir == 'backward') {
          pump();
          continue;
        }

        if (dir == 'forward') {
          scanned++;
          final block = result['block'];
          if (block is Map<String, dynamic>) {
            final txs = block['transactions'];
            if (txs is List) {
              for (final t in txs) {
                if (t is! Map<String, dynamic>) continue;
                final id = t['id'];
                if (id is! String) continue;
                if (id.toLowerCase() != want) continue;

                Map<String, dynamic>? aux;
                final rawAux = t['auxiliaryData'] ?? t['metadata'];
                if (rawAux is Map<String, dynamic>) {
                  aux = rawAux;
                } else if (rawAux != null) {
                  aux = <String, dynamic>{'value': rawAux};
                }

                onProgress?.call(scanned, tipHeight);

                return OgmiosAuxDataFetchResult(
                  found: true,
                  transactionId: id,
                  blockHeight: _asInt(block['height']),
                  blockSlot: _asInt(block['slot']),
                  auxiliaryData: aux,
                  transactionJson: t,
                  scannedForwardBlocks: scanned,
                );
              }
            }
          }
          onProgress?.call(scanned, tipHeight);
        }

        pump();
      }

      onProgress?.call(scanned, tipHeight);
      return OgmiosAuxDataFetchResult(
        found: false,
        transactionId: want,
        scannedForwardBlocks: scanned,
      );
    } finally {
      await queue.cancel();
      await channel.sink.close();
    }
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}

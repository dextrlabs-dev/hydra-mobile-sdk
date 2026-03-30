// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:hydra_demo/services/ogmios_aux_data_fetcher.dart';

/// One-off: fetch tx auxiliary data via Ogmios chain-sync on :1337.
/// Usage: dart run tool/fetch_aux_for_tx.dart [txId]
void main(List<String> args) async {
  final id = args.isNotEmpty
      ? args[0]
      : '0f2e2d28bdb4365991de3dfa69ead2e2341535be442b5e56666ad763a60778bc';
  final r = await OgmiosAuxDataFetcher.fetchAuxiliaryDataForTransaction(
    transactionId: id,
    httpBaseUrl: 'http://127.0.0.1:1337',
    // Must exceed current tip height (chain-sync walks from origin); cap was 500k and missed txs on longer chains.
    maxForwardBlocks: 2000000,
    onProgress: (s, tip) {
      if (s % 500 == 0 || s < 5) {
        stderr.writeln('scanned=$s tip=$tip');
      }
    },
  );
  final summary = <String, dynamic>{
    'found': r.found,
    'transactionId': r.transactionId,
    'blockHeight': r.blockHeight,
    'blockSlot': r.blockSlot,
    'auxiliaryData': r.auxiliaryData,
    'scannedForwardBlocks': r.scannedForwardBlocks,
    'transactionTopLevelKeys': r.transactionJson?.keys.toList(),
  };
  stdout.writeln(JsonEncoder.withIndent('  ').convert(summary));
  final tj = r.transactionJson;
  if (tj != null) {
    stdout.writeln(
      'auxiliaryDataRaw: ${tj['auxiliaryData'] ?? tj['metadata'] ?? '(none on this tx)'}',
    );
  }
}

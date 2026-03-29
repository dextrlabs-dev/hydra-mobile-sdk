import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hydra_client/hydra_client.dart';

import 'fixtures/commit_sample_fixture.dart';
import 'services/hydra_commit_submit.dart';

class ConnectionTab extends StatefulWidget {
  const ConnectionTab({
    super.key,
    this.onGreetingsSlot,
    this.onHydraConfig,
  });

  final ValueChanged<int?>? onGreetingsSlot;
  final ValueChanged<HydraClientConfig?>? onHydraConfig;

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  /// Android emulator → host Hydra: `10.0.2.2`. Desktop/web: `127.0.0.1`.
  final _hostCtrl = TextEditingController(text: '10.0.2.2');
  final _portCtrl = TextEditingController(text: '4001');
  final _commitUtxoJsonCtrl = TextEditingController();
  final _commitMnemonicCtrl = TextEditingController();
  final _sideLoadJsonCtrl = TextEditingController();
  final _decommitJsonCtrl = TextEditingController();
  final _recoverTxIdCtrl = TextEditingController();
  final _log = <String>[];

  HydraSession? _session;
  StreamSubscription<HydraInboundMessage>? _sub;
  String _status = 'Disconnected';
  bool _commitBusy = false;
  String? _commitResult;

  HydraClientConfig? _apiConfig;
  String _restInspectorText = 'Connect, then use REST actions below.';
  String? _lastHeadTag;

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_session?.dispose());
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _commitUtxoJsonCtrl.dispose();
    _commitMnemonicCtrl.dispose();
    _sideLoadJsonCtrl.dispose();
    _decommitJsonCtrl.dispose();
    _recoverTxIdCtrl.dispose();
    super.dispose();
  }

  void _append(String line) {
    setState(() {
      _log.insert(0, line);
      if (_log.length > 200) _log.removeLast();
    });
  }

  int? _slotFromGreetings(HydraGreetings g) {
    final s = g.json['currentSlot'];
    if (s is int) return s;
    if (s is num) return s.toInt();
    if (s is Map<String, dynamic>) {
      final inner = s['slot'];
      if (inner is int) return inner;
      if (inner is num) return inner.toInt();
    }
    return null;
  }

  HydraClientConfig _configFromFields() {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 4001;
    return HydraClientConfig(host: host, port: port, history: true);
  }

  Future<void> _withHttp(Future<void> Function(HydraHttpClient h) fn) async {
    final cfg = _apiConfig;
    if (cfg == null) {
      if (mounted) {
        setState(() => _restInspectorText = 'Connect first.');
      }
      return;
    }
    final client = HydraHttpClient(config: cfg);
    try {
      await fn(client);
    } catch (e) {
      if (mounted) {
        setState(() => _restInspectorText = 'Error: $e');
      }
      _append('HTTP error: $e');
    } finally {
      client.close();
    }
  }

  void _showResponse(http.Response r, String label) {
    final b = utf8.decode(r.bodyBytes);
    if (!mounted) return;
    setState(() {
      _restInspectorText = '$label → ${r.statusCode}\n$b';
    });
    final short = b.length > 240 ? '${b.substring(0, 240)}…' : b;
    _append('$label ${r.statusCode}: $short');
  }

  Future<void> _refreshHead() async {
    await _withHttp((h) async {
      final r = await h.getHeadState();
      final parsed = HydraHeadState.tryParse(utf8.decode(r.bodyBytes));
      if (mounted) setState(() => _lastHeadTag = parsed?.tag);
      _showResponse(r, 'GET /head');
    });
  }

  Future<void> _getSnapshotUtxo() async {
    await _withHttp((h) async {
      final r = await h.getSnapshotUtxo();
      _showResponse(r, 'GET /snapshot/utxo');
    });
  }

  Future<void> _getSnapshotLastSeen() async {
    await _withHttp((h) async {
      final r = await h.getSnapshotLastSeen();
      _showResponse(r, 'GET /snapshot/last-seen');
    });
  }

  Future<void> _getSnapshot() async {
    await _withHttp((h) async {
      final r = await h.getSnapshot();
      _showResponse(r, 'GET /snapshot');
    });
  }

  Future<void> _getHeadInitialization() async {
    await _withHttp((h) async {
      final r = await h.getHeadInitialization();
      _showResponse(r, 'GET /head-initialization');
    });
  }

  Future<void> _postSideLoadSnapshot() async {
    final raw = _sideLoadJsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _restInspectorText = 'Paste ConfirmedSnapshot JSON for POST /snapshot.');
      return;
    }
    late final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      } else {
        setState(() => _restInspectorText = 'Body must be a JSON object.');
        return;
      }
    } catch (e) {
      setState(() => _restInspectorText = 'Invalid JSON: $e');
      return;
    }
    await _withHttp((h) async {
      final r = await h.postSnapshot(body);
      _showResponse(r, 'POST /snapshot (side-load)');
    });
  }

  Future<void> _postDecommit() async {
    final raw = _decommitJsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _restInspectorText = 'Paste Transaction JSON for POST /decommit.');
      return;
    }
    late final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      } else {
        setState(() => _restInspectorText = 'Body must be a JSON object.');
        return;
      }
    } catch (e) {
      setState(() => _restInspectorText = 'Invalid JSON: $e');
      return;
    }
    await _withHttp((h) async {
      final r = await h.postDecommit(body);
      _showResponse(r, 'POST /decommit');
    });
  }

  Future<void> _deleteRecoverDeposit() async {
    final txId = _recoverTxIdCtrl.text.trim();
    if (txId.isEmpty) {
      setState(() => _restInspectorText = 'Enter deposit tx id for DELETE /commits/{txId}.');
      return;
    }
    await _withHttp((h) async {
      final r = await h.deleteCommitTx(txId);
      _showResponse(r, 'DELETE /commits/…');
    });
  }

  Future<void> _connect() async {
    await _disconnect();
    final config = _configFromFields();
    final session = HydraSession(config);
    setState(() {
      _session = session;
      _status = 'Connecting…';
    });
    widget.onHydraConfig?.call(null);
    try {
      await session.connect();
      _sub = session.messages.listen(
        (m) {
          if (m is HydraGreetings) {
            widget.onGreetingsSlot?.call(_slotFromGreetings(m));
          }
          _append(_formatMessage(m));
        },
        onError: (Object e) {
          _append('ERROR: $e');
        },
      );
      setState(() {
        _status = 'Connected';
        _apiConfig = config;
      });
      widget.onHydraConfig?.call(config);
      _append('WebSocket open: ${config.webSocketUri}');
    } catch (e) {
      setState(() => _status = 'Error');
      _append('Connect failed: $e');
      await session.dispose();
      setState(() {
        _session = null;
        _apiConfig = null;
      });
      widget.onHydraConfig?.call(null);
    }
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _session?.dispose();
    setState(() {
      _session = null;
      _status = 'Disconnected';
      _apiConfig = null;
      _lastHeadTag = null;
    });
    widget.onGreetingsSlot?.call(null);
    widget.onHydraConfig?.call(null);
  }

  void _sendWs(Map<String, dynamic> input, String label) {
    final s = _session;
    if (s == null) return;
    try {
      s.send(input);
      _append('Sent $label');
    } catch (e) {
      _append('Send failed ($label): $e');
    }
  }

  void _sendInit() => _sendWs(ClientInput.init(), 'Init');
  void _sendClose() => _sendWs(ClientInput.close(), 'Close');
  void _sendSafeClose() => _sendWs(ClientInput.safeClose(), 'SafeClose');
  void _sendContest() => _sendWs(ClientInput.contest(), 'Contest');
  void _sendFanout() => _sendWs(ClientInput.fanout(), 'Fanout');

  void _loadSampleCommitFixture() {
    setState(() {
      _commitUtxoJsonCtrl.text = kSampleCommitUtxoJson.trim();
      _commitMnemonicCtrl.text = kSampleBip39Mnemonic;
      _commitResult = null;
    });
    _append('Loaded sample UTxO JSON + test mnemonic (preview demo only).');
  }

  Future<void> _submitCommit() async {
    final session = _session;
    if (session == null) {
      setState(() => _commitResult = 'Connect first.');
      return;
    }
    final config = _apiConfig ?? _configFromFields();

    final raw = _commitUtxoJsonCtrl.text.trim();
    final mnemonic = _commitMnemonicCtrl.text.trim();
    if (raw.isEmpty || mnemonic.isEmpty) {
      setState(() => _commitResult = 'Paste L1 UTxO JSON and enter mnemonic.');
      return;
    }

    late final Map<String, dynamic> utxo;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _commitResult = 'JSON must be a single object (txHash#ix → output).');
        return;
      }
      utxo = decoded;
    } catch (e) {
      setState(() => _commitResult = 'Invalid JSON: $e');
      return;
    }

    setState(() {
      _commitBusy = true;
      _commitResult = null;
    });

    try {
      final msg = await HydraCommitSubmit.draftSignAndSubmitL1Commit(
        config: config,
        mnemonic: mnemonic,
        utxoToCommit: utxo,
      );
      if (!mounted) return;
      setState(() {
        _commitBusy = false;
        _commitResult = 'L1 commit submitted: $msg';
      });
      _append('Commit tx submitted to L1: $msg');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commitBusy = false;
        _commitResult = 'Error: $e';
      });
      _append('Commit failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWs = _session != null;
    final canHttp = _apiConfig != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydra client demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(_status)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              flex: 3,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'hydra-node host',
                        border: OutlineInputBorder(),
                        helperText: 'Emulator: 10.0.2.2 · Desktop: 127.0.0.1',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'API port',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(onPressed: _connect, child: const Text('Connect')),
                        OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
                        FilledButton.tonal(
                          onPressed: canWs ? _sendInit : null,
                          child: const Text('Send Init'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('Head protocol (WebSocket)'),
                      subtitle: Text(
                        _lastHeadTag != null
                            ? 'Last GET /head tag: $_lastHeadTag'
                            : 'Use GET /head (REST) to refresh tag',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: canWs ? _sendClose : null,
                              child: const Text('Close'),
                            ),
                            FilledButton.tonal(
                              onPressed: canWs ? _sendSafeClose : null,
                              child: const Text('SafeClose'),
                            ),
                            FilledButton.tonal(
                              onPressed: canWs ? _sendContest : null,
                              child: const Text('Contest'),
                            ),
                            FilledButton.tonal(
                              onPressed: canWs ? _sendFanout : null,
                              child: const Text('Fanout'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('REST: head & snapshots'),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: canHttp ? _refreshHead : null,
                              child: const Text('GET /head'),
                            ),
                            FilledButton.tonal(
                              onPressed: canHttp ? _getSnapshotUtxo : null,
                              child: const Text('GET /snapshot/utxo'),
                            ),
                            FilledButton.tonal(
                              onPressed: canHttp ? _getSnapshotLastSeen : null,
                              child: const Text('GET /snapshot/last-seen'),
                            ),
                            FilledButton.tonal(
                              onPressed: canHttp ? _getSnapshot : null,
                              child: const Text('GET /snapshot'),
                            ),
                            FilledButton.tonal(
                              onPressed: canHttp ? _getHeadInitialization : null,
                              child: const Text('GET /head-initialization'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(8),
                              child: SelectableText(
                                _restInspectorText,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('Advanced: side-load / decommit / recover'),
                      subtitle: const Text('Danger: can break head state if misused'),
                      children: [
                        TextField(
                          controller: _sideLoadJsonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'POST /snapshot — ConfirmedSnapshot JSON',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        FilledButton.tonal(
                          onPressed: canHttp ? _postSideLoadSnapshot : null,
                          child: const Text('POST /snapshot'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _decommitJsonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'POST /decommit — Transaction JSON',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        FilledButton.tonal(
                          onPressed: canHttp ? _postDecommit : null,
                          child: const Text('POST /decommit'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _recoverTxIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'DELETE /commits/{txId} — deposit tx id (hex)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: canHttp ? _deleteRecoverDeposit : null,
                          child: const Text('DELETE /commits/…'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('Commit UTxO to head (L1)'),
                      subtitle: const Text('After Init, draft commit → sign → submit to Cardano'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Paste the object from: cardano-cli query utxo --address <addr> '
                            '--testnet-magic 42 --output-json\n'
                            'Keys must be txHash#ix; values need address + value.lovelace. '
                            'Same mnemonic as Dice game (${HydraCommitSubmit.defaultPaymentPath}).',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _loadSampleCommitFixture,
                            icon: const Icon(Icons.content_paste_go, size: 18),
                            label: const Text('Load sample (preview testnet)'),
                          ),
                        ),
                        TextField(
                          controller: _commitUtxoJsonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'L1 UTxO JSON',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 6,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commitMnemonicCtrl,
                          decoration: const InputDecoration(
                            labelText: 'BIP39 mnemonic (owns those UTxOs)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: (canWs && !_commitBusy) ? _submitCommit : null,
                          icon: _commitBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload),
                          label: Text(_commitBusy ? 'Submitting…' : 'Draft, sign & submit commit'),
                        ),
                        if (_commitResult != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            _commitResult!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Log (newest first)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Flexible(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _log.length,
                  itemBuilder: (context, i) => SelectableText(
                    _log[i],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMessage(HydraInboundMessage m) {
  return switch (m) {
    HydraGreetings g => 'Greetings headStatus=${g.headStatus} version=${g.hydraNodeVersion}',
    HydraTimedServerOutput t => '[${t.seq}] ${t.tag}',
    HydraInvalidInput i => 'InvalidInput: ${i.reason}',
    HydraRawMessage r => 'Raw: ${r.json['tag'] ?? r.json.keys.join(',')}',
  };
}

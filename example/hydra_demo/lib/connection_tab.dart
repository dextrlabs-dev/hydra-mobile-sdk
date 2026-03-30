import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hydra_client/hydra_client.dart';

import 'fixtures/commit_sample_fixture.dart';
import 'services/hydra_commit_submit.dart';
<<<<<<< Updated upstream
import 'services/devnet_utxo_loader.dart';
import 'services/ogmios_utxo_loader.dart';
import 'services/prefs_hydra_state_store.dart';
=======
>>>>>>> Stashed changes

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

  String? _derivedAddr;
  Map<String, dynamic>? _l1UtxoByTxIn;
  final Set<String> _selectedTxIns = <String>{};
  bool _utxoBusy = false;
  String? _utxoLoadResult;
  bool _useOgmiosIndexer = true;

  HydraHeadFacade? _facade;
  StreamSubscription<HydraInboundMessage>? _sub;
  StreamSubscription<HydraConnectionState>? _connSub;
  String _status = 'Disconnected';
  bool _autoReconnect = true;
  bool _commitBusy = false;
  String? _commitResult;

  HydraClientConfig? _apiConfig;
  String _restInspectorText = 'Connect, then use REST actions below.';
  String? _lastHeadTag;

  @override
  void dispose() {
    _sub?.cancel();
    _connSub?.cancel();
    unawaited(_facade?.dispose());
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
    if (line.startsWith('SyncedStatusReport')) {
      // Prevent the periodic status report from flooding the log UI.
      return;
    }
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
    final f = _facade;
    if (f == null ||
        f.connectionStateValue != HydraConnectionState.connected) {
      if (mounted) {
        setState(() => _restInspectorText = 'Connect first.');
      }
      return;
    }
    try {
      await fn(f.hydraHttp);
    } catch (e) {
      if (mounted) {
        setState(() => _restInspectorText = 'Error: $e');
      }
      _append('HTTP error: $e');
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

  String _statusLabel(HydraConnectionState s) => switch (s) {
        HydraConnectionState.disconnected => 'Disconnected',
        HydraConnectionState.connecting => 'Connecting…',
        HydraConnectionState.connected => 'Connected',
        HydraConnectionState.reconnecting => 'Reconnecting…',
      };

  Future<void> _connect() async {
    await _disconnect();
    final config = _configFromFields();
    if (!mounted) {
      return;
    }

    final store = InMemoryHydraStateStore();
    final syncPolicy = HydraSyncPolicy.none;

    final facade = HydraHeadFacade(
      config: config,
      reconnectPolicy: HydraReconnectPolicy(autoReconnect: _autoReconnect),
      syncPolicy: syncPolicy,
      stateStore: store,
      onSeqGap: (last, next) =>
          _append('Seq gap: last=$last incoming=$next (snapshot hint refresh)'),
    );

    setState(() {
      _facade = facade;
      _status = 'Connecting…';
    });
    widget.onHydraConfig?.call(null);

    await _connSub?.cancel();
    _connSub = facade.connectionState.listen((s) {
      if (!mounted) {
        return;
      }
      setState(() => _status = _statusLabel(s));
    });

    try {
      await _sub?.cancel();
      _sub = facade.messages.listen(
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
      await facade.connect(restoreSeq: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _apiConfig = config;
      });
      widget.onHydraConfig?.call(config);
      _append('HydraHeadFacade WebSocket: ${config.webSocketUri}');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Error');
      _append('Connect failed: $e');
      await _connSub?.cancel();
      _connSub = null;
      await _sub?.cancel();
      _sub = null;
      await facade.dispose();
      setState(() {
        _facade = null;
        _apiConfig = null;
      });
      widget.onHydraConfig?.call(null);
    }
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _connSub?.cancel();
    _connSub = null;
    await _facade?.dispose();
    setState(() {
      _facade = null;
      _status = 'Disconnected';
      _apiConfig = null;
      _lastHeadTag = null;
    });
    widget.onGreetingsSlot?.call(null);
    widget.onHydraConfig?.call(null);
  }

  void _sendInit() {
    final f = _facade;
    if (f == null) {
      return;
    }
    try {
      f.sendInit();
      _append('Sent Init');
    } catch (e) {
      _append('Send failed (Init): $e');
    }
  }

  void _sendClose() {
    final f = _facade;
    if (f == null) {
      return;
    }
    try {
      f.sendClose();
      _append('Sent Close');
    } catch (e) {
      _append('Send failed (Close): $e');
    }
  }

  void _sendSafeClose() {
    final f = _facade;
    if (f == null) {
      return;
    }
    try {
      f.sendSafeClose();
      _append('Sent SafeClose');
    } catch (e) {
      _append('Send failed (SafeClose): $e');
    }
  }

  void _sendContest() {
    final f = _facade;
    if (f == null) {
      return;
    }
    try {
      f.sendContest();
      _append('Sent Contest');
    } catch (e) {
      _append('Send failed (Contest): $e');
    }
  }

  void _sendFanout() {
    final f = _facade;
    if (f == null) {
      return;
    }
    try {
      f.sendFanout();
      _append('Sent Fanout');
    } catch (e) {
      _append('Send failed (Fanout): $e');
    }
  }

  void _loadSampleCommitFixture() {
    setState(() {
      _commitUtxoJsonCtrl.text = kSampleCommitUtxoJson.trim();
      _commitMnemonicCtrl.text = kSampleBip39Mnemonic;
      _commitResult = null;
    });
    _append('Loaded sample UTxO JSON + test mnemonic (preview demo only).');
  }

  Future<void> _loadL1UtxosFromMnemonic() async {
    final mnemonic = _commitMnemonicCtrl.text.trim();
    if (mnemonic.isEmpty) {
      setState(() => _utxoLoadResult = 'Enter mnemonic first.');
      return;
    }
    setState(() {
      _utxoBusy = true;
      _utxoLoadResult = null;
      _derivedAddr = null;
      _l1UtxoByTxIn = null;
      _selectedTxIns.clear();
    });
    try {
      final addr = await DevnetUtxoLoader.deriveBaseTestnetAddressFromMnemonic(
        mnemonic,
      );
      final utxo = _useOgmiosIndexer
          ? await OgmiosUtxoLoader.queryUtxoByAddress(address: addr)
          : await DevnetUtxoLoader.queryUtxoJsonBestEffort(address: addr);
      if (!mounted) return;
      setState(() {
        _utxoBusy = false;
        _derivedAddr = addr;
        _l1UtxoByTxIn = utxo;
        _utxoLoadResult =
            utxo.isEmpty ? 'No UTxOs at derived address.' : 'Loaded ${utxo.length} UTxO(s).';
      });
      _append('Derived address: $addr');
      _append(
        'Loaded ${utxo.length} L1 UTxO(s) via ${_useOgmiosIndexer ? 'Ogmios' : 'cardano-cli'}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _utxoBusy = false;
        _utxoLoadResult = 'Load failed: $e';
      });
      _append('Load L1 UTxO failed: $e');
    }
  }

  int _lovelaceOf(dynamic utxoOut) {
    if (utxoOut is! Map<String, dynamic>) return 0;
    final value = utxoOut['value'];
    if (value is! Map) return 0;
    final l = value['lovelace'];
    if (l is int) return l;
    if (l is num) return l.toInt();
    return 0;
  }

  Map<String, dynamic> _selectedUtxoMap() {
    final utxo = _l1UtxoByTxIn;
    if (utxo == null) return <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final k in _selectedTxIns) {
      final v = utxo[k];
      if (v != null) out[k] = v;
    }
    return out;
  }

  Future<void> _commitSelectedUtxos() async {
    final f = _facade;
    if (f == null || f.connectionStateValue != HydraConnectionState.connected) {
      setState(() => _commitResult = 'Connect first.');
      return;
    }
    final mnemonic = _commitMnemonicCtrl.text.trim();
    if (mnemonic.isEmpty) {
      setState(() => _commitResult = 'Enter mnemonic first.');
      return;
    }
    final selected = _selectedUtxoMap();
    if (selected.isEmpty) {
      setState(() => _commitResult = 'Select at least one UTxO.');
      return;
    }

    setState(() {
      _commitBusy = true;
      _commitResult = null;
    });
    try {
      final msg = await HydraCommitSubmit.draftSignAndSubmitL1Commit(
        config: _apiConfig ?? _configFromFields(),
        mnemonic: mnemonic,
        utxoToCommit: selected,
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

  Future<void> _submitCommit() async {
    final f = _facade;
    if (f == null ||
        f.connectionStateValue != HydraConnectionState.connected) {
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
    final canWs = _facade != null &&
        _facade!.connectionStateValue == HydraConnectionState.connected;
    final canHttp = canWs;
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-reconnect WebSocket'),
                      subtitle: const Text('Backoff up to 3s between attempts'),
                      value: _autoReconnect,
                      onChanged: _facade != null
                          ? null
                          : (v) {
                              setState(() => _autoReconnect = v);
                            },
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
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Use Ogmios indexer for UTxOs'),
                          subtitle: const Text('Queries http://127.0.0.1:1337 (JSON-RPC)'),
                          value: _useOgmiosIndexer,
                          onChanged: _utxoBusy
                              ? null
                              : (v) => setState(() => _useOgmiosIndexer = v),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _utxoBusy ? null : _loadL1UtxosFromMnemonic,
                          icon: _utxoBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          label: const Text('Load L1 UTxOs from mnemonic'),
                        ),
                        if (_derivedAddr != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            'Derived addr_test:\n$_derivedAddr',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                        ],
                        if (_utxoLoadResult != null) ...[
                          const SizedBox(height: 8),
                          Text(_utxoLoadResult!),
                        ],
                        if (_l1UtxoByTxIn != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView(
                                children: _l1UtxoByTxIn!.entries.map((e) {
                                  final txIn = e.key;
                                  final lovelace = _lovelaceOf(e.value);
                                  final selected = _selectedTxIns.contains(txIn);
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedTxIns.add(txIn);
                                        } else {
                                          _selectedTxIns.remove(txIn);
                                        }
                                        final map = _selectedUtxoMap();
                                        _commitUtxoJsonCtrl.text =
                                            const JsonEncoder.withIndent('  ')
                                                .convert(map);
                                      });
                                    },
                                    title: Text(
                                      txIn,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                    subtitle: Text('$lovelace lovelace'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: (canWs && !_commitBusy) ? _commitSelectedUtxos : null,
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              'Commit selected (${_selectedTxIns.length})',
                            ),
                          ),
                        ],
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
    HydraGreetings g =>
      'Greetings headStatus=${g.headStatus} version=${g.hydraNodeVersion}',
    HydraTxValid v =>
      '[${v.seq}] TxValid id=${v.transactionId ?? v.json['transactionId']}',
    HydraTxInvalid i =>
      '[${i.seq}] TxInvalid ${i.validationError}',
    HydraServerSnapshot s => '[${s.seq}] Snapshot',
    HydraTimedServerOutput t => '[${t.seq}] ${t.tag}',
    HydraInvalidInput i => 'InvalidInput: ${i.reason}',
    HydraRawMessage r => _formatRaw(r),
  };
}

String _formatRaw(HydraRawMessage r) {
  final tag = r.json['tag'];
  if (tag == 'SyncedStatusReport') {
    // Hydra can emit these periodically; they're noisy in a UI log.
    // Still show a concise line instead of the raw tag spam.
    final st = r.json['chainSyncedStatus'] ?? r.json['synced'] ?? '';
    return 'SyncedStatusReport ${st.toString()}'.trim();
  }
  return 'Raw: ${tag ?? r.json.keys.join(',')}';
}

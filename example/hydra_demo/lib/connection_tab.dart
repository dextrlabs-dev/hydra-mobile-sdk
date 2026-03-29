import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hydra_client/hydra_client.dart';

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
  final _hostCtrl = TextEditingController(text: '127.0.0.1');
  final _portCtrl = TextEditingController(text: '4001');
  final _commitUtxoJsonCtrl = TextEditingController();
  final _commitMnemonicCtrl = TextEditingController();
  final _log = <String>[];

  HydraSession? _session;
  StreamSubscription<HydraInboundMessage>? _sub;
  String _status = 'Disconnected';
  bool _commitBusy = false;
  String? _commitResult;

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_session?.dispose());
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _commitUtxoJsonCtrl.dispose();
    _commitMnemonicCtrl.dispose();
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

  Future<void> _connect() async {
    await _disconnect();
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 4001;
    final config = HydraClientConfig(host: host, port: port, history: true);
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
      setState(() => _status = 'Connected');
      widget.onHydraConfig?.call(config);
      _append('WebSocket open: ${config.webSocketUri}');
    } catch (e) {
      setState(() => _status = 'Error');
      _append('Connect failed: $e');
      await session.dispose();
      setState(() => _session = null);
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
    });
    widget.onGreetingsSlot?.call(null);
    widget.onHydraConfig?.call(null);
  }

  void _sendInit() {
    final s = _session;
    if (s == null) return;
    try {
      s.send(ClientInput.init());
      _append('Sent Init');
    } catch (e) {
      _append('Send failed: $e');
    }
  }

  Future<void> _submitCommit() async {
    final session = _session;
    if (session == null) {
      setState(() => _commitResult = 'Connect first.');
      return;
    }
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 4001;
    final config = HydraClientConfig(host: host, port: port, history: true);

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
            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: 'hydra-node host',
                border: OutlineInputBorder(),
                helperText: 'Emulator on same PC: 10.0.2.2; remote: server IP',
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
                  onPressed: _session != null ? _sendInit : null,
                  child: const Text('Send Init'),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  onPressed: (_session != null && !_commitBusy) ? _submitCommit : null,
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
            const SizedBox(height: 8),
            const Text('Log (newest first)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Expanded(
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

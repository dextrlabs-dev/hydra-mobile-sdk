import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hydra_client/hydra_client.dart';

import 'fixtures/commit_sample_fixture.dart';
import 'services/dice_hydra_submit.dart';

/// Simple dice game: each roll submits an L2 transaction (metadata) via
/// [DiceHydraSubmit] using [catalyst_cardano_serialization] + BIP39 signing.
class DiceGameTab extends StatefulWidget {
  const DiceGameTab({
    super.key,
    required this.currentSlot,
    this.hydraConfig,
  });

  final int? currentSlot;
  final HydraClientConfig? hydraConfig;

  @override
  State<DiceGameTab> createState() => _DiceGameTabState();
}

class _DiceGameTabState extends State<DiceGameTab> {
  final _mnemonicCtrl = TextEditingController();
  int _lastRoll = 1;
  int _round = 0;
  int _score = 0;
  bool _busy = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _mnemonicCtrl.text = kSampleBip39Mnemonic;
    }
  }

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  Future<void> _rollAndSubmit() async {
    final cfg = widget.hydraConfig;
    if (cfg == null) {
      setState(() => _lastResult = 'Connect on the Hydra tab first.');
      return;
    }
    final mnemonic = _mnemonicCtrl.text.trim();
    if (mnemonic.isEmpty) {
      setState(() => _lastResult = 'Enter a BIP39 mnemonic that owns a UTxO in the head.');
      return;
    }
    final slot = widget.currentSlot;
    if (slot == null) {
      setState(() => _lastResult = 'Wait for Greetings (chain slot) from Hydra, then try again.');
      return;
    }

    setState(() {
      _busy = true;
      _lastResult = null;
    });

    final roll = 1 + (DateTime.now().millisecondsSinceEpoch % 6);
    final ttl = slot + 50000;

    try {
      final body = await DiceHydraSubmit.submitDiceRoll(
        config: cfg,
        mnemonic: mnemonic,
        diceValue: roll,
        roundIndex: _round,
        ttlSlot: ttl,
      );
      if (!mounted) return;
      setState(() {
        _lastRoll = roll;
        _round++;
        _score += roll;
        _busy = false;
        _lastResult = 'OK: $body';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastResult = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.hydraConfig;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydra dice (L2 tx)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.65),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Devnet / demo only',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: const [
                        TextSpan(
                          text:
                              'Requires an open Hydra head with at least one UTxO whose address '
                              'matches payment key ',
                        ),
                        TextSpan(
                          text: "m/1852'/1815'/0'/0/0",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' from your mnemonic. Use the same host/port as on the Hydra tab.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Hydra target'),
            subtitle: Text(
              cfg == null
                  ? 'Not connected — open Hydra tab and tap Connect.'
                  : '${cfg.host}:${cfg.port} (slot hint: ${widget.currentSlot ?? "?"})',
            ),
          ),
          TextField(
            controller: _mnemonicCtrl,
            decoration: const InputDecoration(
              labelText: 'BIP39 mnemonic',
              border: OutlineInputBorder(),
              helperText: 'Never use mainnet funds. Dev / test wallets only.',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _rollAndSubmit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.casino),
                  label: Text(_busy ? 'Submitting…' : 'Roll & submit L2 tx'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Last roll: $_lastRoll', style: Theme.of(context).textTheme.headlineSmall),
          Text('Round: $_round  ·  Running score: $_score'),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _lastResult!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

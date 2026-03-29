import 'dart:convert';

import 'messages.dart';

/// Parses one WebSocket text frame from `hydra-node`.
HydraInboundMessage parseHydraMessage(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    return HydraRawMessage({'value': decoded});
  }
  final m = Map<String, dynamic>.from(decoded);

  if (_isInvalidInput(m)) {
    return HydraInvalidInput(
      reason: m['reason']! as String,
      input: m['input']! as String,
    );
  }

  if (_isGreetings(m)) {
    return HydraGreetings(m);
  }

  final tag = m['tag'];
  final seqRaw = m['seq'];
  final seq = seqRaw is int
      ? seqRaw
      : seqRaw is num
          ? seqRaw.toInt()
          : null;
  if (tag is String && seq != null) {
    return HydraTimedServerOutput(
      tag: tag,
      seq: seq,
      timestamp: m['timestamp'] as String?,
      json: m,
    );
  }

  if (tag is String) {
    return HydraRawMessage(m);
  }

  return HydraRawMessage(m);
}

bool _isInvalidInput(Map<String, dynamic> m) =>
    m.containsKey('reason') && m.containsKey('input') && m['tag'] == null;

bool _isGreetings(Map<String, dynamic> m) {
  if (m['tag'] == 'Greetings') return true;
  return m.containsKey('headStatus') &&
      m.containsKey('hydraNodeVersion') &&
      m.containsKey('me') &&
      m['seq'] == null;
}

/// Parsed inbound WebSocket payload from `hydra-node`.
sealed class HydraInboundMessage {
  const HydraInboundMessage();
}

/// `Greetings` — sent on each connection; marks API server readiness.
final class HydraGreetings extends HydraInboundMessage {
  const HydraGreetings(this.json);

  final Map<String, dynamic> json;

  dynamic get me => json['me'];
  String? get headStatus => json['headStatus'] as String?;
  String? get hydraNodeVersion => json['hydraNodeVersion'] as String?;
  dynamic get hydraHeadId => json['hydraHeadId'];
  dynamic get snapshotUtxo => json['snapshotUtxo'];
}

/// A timed server output: protocol event with `seq` and `timestamp`.
final class HydraTimedServerOutput extends HydraInboundMessage {
  const HydraTimedServerOutput({
    required this.tag,
    required this.seq,
    required this.timestamp,
    required this.json,
  });

  final String tag;
  final int seq;
  final String? timestamp;
  final Map<String, dynamic> json;
}

/// Malformed client input response (`InvalidInput` in hydra-node).
final class HydraInvalidInput extends HydraInboundMessage {
  const HydraInvalidInput({required this.reason, required this.input});

  final String reason;
  final String input;
}

/// Fallback when classification is unknown (forward-compatible).
final class HydraRawMessage extends HydraInboundMessage {
  const HydraRawMessage(this.json);

  final Map<String, dynamic> json;
}

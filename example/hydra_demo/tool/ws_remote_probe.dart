// Probe Hydra client WebSocket API (no Flutter).
// From example/hydra_demo: dart run tool/ws_remote_probe.dart
import 'dart:async';
import 'dart:io';

import 'package:hydra_client/hydra_client.dart';

const _host = '139.59.94.155';
const _port = 4001;

Future<void> main() async {
  final config = HydraClientConfig(host: _host, port: _port, history: true);
  stderr.writeln('Connecting ${config.webSocketUri}');
  final session = HydraSession(config);
  try {
    await session.connect();
    stderr.writeln('WebSocket ready, waiting for Greetings…');
    final done = Completer<void>();
    late final StreamSubscription<HydraInboundMessage> sub;
    sub = session.messages.listen(
      (m) {
        stderr.writeln('<= ${_summarize(m)}');
        if (m is HydraGreetings && !done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object e, StackTrace st) {
        stderr.writeln('stream error: $e');
        if (!done.isCompleted) {
          done.completeError(e, st);
        }
      },
    );
    await done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('No Greetings within 20s'),
    );
    await sub.cancel();
    stdout.writeln('OK: Greetings from $_host:$_port');
    exit(0);
  } on Object catch (e, st) {
    stderr.writeln('FAILED: $e');
    stderr.writeln(st);
    exit(1);
  } finally {
    await session.dispose();
  }
}

String _summarize(HydraInboundMessage m) {
  return switch (m) {
    HydraGreetings g =>
      'Greetings headStatus=${g.headStatus} version=${g.hydraNodeVersion}',
    HydraTimedServerOutput t => '[${t.seq}] ${t.tag}',
    HydraInvalidInput i => 'InvalidInput: ${i.reason}',
    HydraRawMessage r => 'Raw: ${r.json['tag'] ?? r.json.keys.join(',')}',
  };
}

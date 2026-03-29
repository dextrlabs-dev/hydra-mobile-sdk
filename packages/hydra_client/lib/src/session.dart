import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'messages.dart';
import 'parser.dart';

/// Live WebSocket session to `hydra-node` client API.
class HydraSession {
  HydraSession(this.config);

  final HydraClientConfig config;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<HydraInboundMessage> _controller =
      StreamController<HydraInboundMessage>.broadcast();

  /// Decoded server messages (includes [HydraGreetings] first on a fresh connection).
  Stream<HydraInboundMessage> get messages => _controller.stream;

  bool get isConnected => _channel != null;

  /// Opens the WebSocket and starts forwarding parsed messages to [messages].
  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    final ch = WebSocketChannel.connect(config.webSocketUri);
    _channel = ch;
    await ch.ready;
    _subscription = ch.stream.listen(
      _onData,
      onError: _controller.addError,
      onDone: () {
        _channel = null;
        _subscription = null;
      },
    );
  }

  void _onData(dynamic data) {
    final text = switch (data) {
      final String s => s,
      final List<int> bytes => utf8.decode(bytes),
      _ => data.toString(),
    };
    try {
      _controller.add(parseHydraMessage(text));
    } catch (e, st) {
      _controller.addError(e, st);
    }
  }

  /// Sends a client input JSON object (e.g. from `ClientInput.init()`).
  void send(Map<String, dynamic> clientInput) {
    final ch = _channel;
    if (ch == null) {
      throw StateError('HydraSession.connect() must be called before send()');
    }
    ch.sink.add(jsonEncode(clientInput));
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _controller.close();
  }
}

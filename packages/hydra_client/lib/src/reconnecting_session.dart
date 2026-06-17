import 'dart:async';

import 'config.dart';
import 'connection_state.dart';
import 'messages.dart';
import 'reconnect_policy.dart';
import 'session.dart';

typedef HydraDelayer = Future<void> Function(Duration duration);

/// WebSocket session with automatic reconnect and a [messages] stream that
/// survives socket cycles.
///
/// Prefer `HydraClientConfig.history: true` when you need replay after reconnect.
class ReconnectingHydraSession {
  ReconnectingHydraSession({
    required this.config,
    this.policy = const HydraReconnectPolicy(),
    HydraDelayer? delayer,
  }) : _delayer = delayer ?? Future<void>.delayed;

  /// Connection settings (host, port, TLS) for each socket this session opens.
  final HydraClientConfig config;

  /// Backoff / auto-reconnect policy applied between socket attempts.
  final HydraReconnectPolicy policy;
  final HydraDelayer _delayer;

  final StreamController<HydraInboundMessage> _messages =
      StreamController<HydraInboundMessage>.broadcast();
  final StreamController<HydraConnectionState> _states =
      StreamController<HydraConnectionState>.broadcast();

  HydraSession? _session;
  StreamSubscription<HydraInboundMessage>? _subscription;

  bool _userStop = true;
  int _failAttempt = 0;

  /// Serializes [connect], socket-drop reconnect, and [disconnect].
  Future<void> _serialized(FutureOr<void> Function() fn) {
    final c = Completer<void>();
    _op = _op.then((_) async {
      try {
        await fn();
        if (!c.isCompleted) c.complete();
      } catch (e, st) {
        if (!c.isCompleted) c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<void> _op = Future<void>.value();

  /// Decoded frames across reconnects (including [HydraGreetings] after each connect).
  Stream<HydraInboundMessage> get messages => _messages.stream;

  /// Transport state (disconnected, connecting, connected, reconnecting).
  Stream<HydraConnectionState> get connectionState => _states.stream;

  HydraConnectionState _currentState = HydraConnectionState.disconnected;

  /// Last emitted connection state.
  HydraConnectionState get state => _currentState;

  bool get isConnected =>
      _currentState == HydraConnectionState.connected && _session != null;

  void _emit(HydraConnectionState s) {
    _currentState = s;
    if (!_states.isClosed) {
      _states.add(s);
    }
  }

  /// Opens the first socket or resumes after [disconnect].
  Future<void> connect() {
    _userStop = false;
    return _serialized(() async {
      if (isConnected) {
        return;
      }
      _failAttempt = 0;
      while (!_userStop) {
        _emit(HydraConnectionState.connecting);
        try {
          await _openSession();
          _failAttempt = 0;
          _emit(HydraConnectionState.connected);
          return;
        } catch (_) {
          if (_userStop) {
            break;
          }
          if (!policy.autoReconnect) {
            await _tearDownSession();
            _emit(HydraConnectionState.disconnected);
            rethrow;
          }
          _emit(HydraConnectionState.reconnecting);
          await _delayer(policy.delayForAttempt(_failAttempt));
          if (_userStop) {
            break;
          }
          _failAttempt++;
        }
      }
      await _tearDownSession();
      _emit(HydraConnectionState.disconnected);
    });
  }

  Future<void> _openSession() async {
    await _tearDownSession();
    final session = HydraSession(config);
    _session = session;
    await session.connect();
    _subscription = session.messages.listen(
      _messages.add,
      onError: _messages.addError,
      onDone: _onSessionDone,
      cancelOnError: false,
    );
  }

  void _onSessionDone() {
    unawaited(
      _serialized(() async {
        await _subscription?.cancel();
        _subscription = null;
        final s = _session;
        _session = null;
        if (s != null) {
          await s.dispose();
        }

        if (_userStop) {
          _emit(HydraConnectionState.disconnected);
          return;
        }
        if (!policy.autoReconnect) {
          _emit(HydraConnectionState.disconnected);
          return;
        }

        _failAttempt = 0;
        while (!_userStop && policy.autoReconnect) {
          _emit(HydraConnectionState.reconnecting);
          await _delayer(policy.delayForAttempt(_failAttempt));
          if (_userStop) {
            break;
          }
          _failAttempt++;
          _emit(HydraConnectionState.connecting);
          try {
            await _openSession();
            _failAttempt = 0;
            _emit(HydraConnectionState.connected);
            return;
          } catch (_) {
            if (_userStop) {
              break;
            }
          }
        }
        await _tearDownSession();
        _emit(HydraConnectionState.disconnected);
      }),
    );
  }

  Future<void> _tearDownSession() async {
    await _subscription?.cancel();
    _subscription = null;
    final s = _session;
    _session = null;
    if (s != null) {
      await s.dispose();
    }
  }

  /// Stops reconnecting and closes the socket.
  Future<void> disconnect() {
    return _serialized(() async {
      _userStop = true;
      await _tearDownSession();
      _emit(HydraConnectionState.disconnected);
    });
  }

  /// Sends a client input (e.g. from [ClientInput]). Throws if not connected.
  void send(Map<String, dynamic> clientInput) {
    final s = _session;
    if (s == null || !s.isConnected) {
      throw StateError(
        'ReconnectingHydraSession is not connected; call connect() first.',
      );
    }
    s.send(clientInput);
  }

  /// Closes broadcast streams; call [disconnect] first in normal apps.
  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _states.close();
  }
}

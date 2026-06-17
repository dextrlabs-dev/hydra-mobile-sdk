import 'dart:async';

import 'package:http/http.dart' as http;

import 'client_input.dart';
import 'config.dart';
import 'connection_state.dart';
import 'hydra_http.dart';
import 'messages.dart';
import 'reconnect_policy.dart';
import 'reconnecting_session.dart';
import 'seq_sync.dart';
import 'signer.dart';
import 'state_store.dart';

/// High-level Hydra head client: reconnecting WebSocket, HTTP, optional seq
/// sync, and typed head lifecycle helpers.
///
/// For low-level control use [HydraSession] / [ReconnectingHydraSession]
/// directly.
class HydraHeadFacade {
  HydraHeadFacade({
    required HydraClientConfig config,
    HydraReconnectPolicy reconnectPolicy = const HydraReconnectPolicy(),
    HydraSyncPolicy syncPolicy = HydraSyncPolicy.none,
    HydraStateStore? stateStore,
    http.Client? httpClient,
    HydraSigner? signer,
    void Function(int lastSeq, int receivedSeq)? onSeqGap,
    this.closeHttpClientOnDispose = true,
  })  : _config = config,
        _store = stateStore ?? InMemoryHydraStateStore(),
        _signer = signer {
    _http = HydraHttpClient(config: config, httpClient: httpClient);
    _session = ReconnectingHydraSession(
      config: config,
      policy: reconnectPolicy,
    );
    _seq = SeqTracker(
      policy: syncPolicy,
      store: _store,
      http: syncPolicy == HydraSyncPolicy.dedupeAndRefreshOnGap ? _http : null,
      onSeqGap: onSeqGap,
    );
  }

  /// When false, [dispose] does not call [HydraHttpClient.close] (e.g. shared [http.Client]).
  final bool closeHttpClientOnDispose;

  final HydraClientConfig _config;
  final HydraStateStore _store;
  final HydraSigner? _signer;

  late final HydraHttpClient _http;
  late final ReconnectingHydraSession _session;
  late final SeqTracker _seq;

  final StreamController<HydraInboundMessage> _messages =
      StreamController<HydraInboundMessage>.broadcast();
  StreamSubscription<HydraInboundMessage>? _sub;

  /// REST client (same host/port/tls as WebSocket). Do not call [HydraHttpClient.close]
  /// until [dispose] unless you control lifecycle.
  HydraHttpClient get hydraHttp => _http;

  /// Connection settings (host, port, TLS) this facade was built with.
  HydraClientConfig get config => _config;

  /// Backing store for persisted seq / snapshot-sync hints.
  HydraStateStore get stateStore => _store;

  /// Optional L2 signer for app-specific transaction building.
  HydraSigner? get signer => _signer;

  /// Last processed timed `seq` when sync policy tracks sequences.
  int? get lastProcessedSeq => _seq.lastSeq;

  /// Seq-filtered / deduped messages (empty until [connect]).
  Stream<HydraInboundMessage> get messages => _messages.stream;

  Stream<HydraConnectionState> get connectionState =>
      _session.connectionState;

  /// Last emitted transport state (see [connectionState] for the live stream).
  HydraConnectionState get connectionStateValue => _session.state;

  /// Subscribes to the message flow, then opens the socket (and reconnects if configured).
  ///
  /// When [restoreSeq] is true (default), the persisted seq is loaded from
  /// [stateStore] first so already-processed messages are skipped after an app
  /// restart; pass false to start fresh and forward every message.
  Future<void> connect({bool restoreSeq = true}) async {
    await _sub?.cancel();
    _sub = null;
    if (restoreSeq) {
      await _seq.restore();
    } else {
      _seq.reset();
    }
    _sub = _session.messages
        .asyncMap(_seq.process)
        .where((m) => m != null)
        .map((m) => m!)
        .listen(_messages.add, onError: _messages.addError);
    await _session.connect();
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _session.disconnect();
  }

  void sendInit() => _session.send(ClientInput.init());

  void sendClose() => _session.send(ClientInput.close());

  void sendSafeClose() => _session.send(ClientInput.safeClose());

  void sendContest() => _session.send(ClientInput.contest());

  void sendFanout() => _session.send(ClientInput.fanout());

  void sendNewTx(Map<String, dynamic> transaction) =>
      _session.send(ClientInput.newTx(transaction));

  void sendRecover(String recoverTxId) =>
      _session.send(ClientInput.recover(recoverTxId));

  void sendDecommit(Map<String, dynamic> decommitTx) =>
      _session.send(ClientInput.decommit(decommitTx));

  void sendSideLoadSnapshot(Map<String, dynamic> snapshot) =>
      _session.send(ClientInput.sideLoadSnapshot(snapshot));

  /// Raw client input JSON (escape hatch).
  void sendRaw(Map<String, dynamic> clientInput) => _session.send(clientInput);

  Future<void> dispose() async {
    await disconnect();
    await _session.dispose();
    await _messages.close();
    if (closeHttpClientOnDispose) {
      _http.close();
    }
  }
}

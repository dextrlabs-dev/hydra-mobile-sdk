import 'dart:async';

import 'hydra_http.dart';
import 'messages.dart';
import 'state_store.dart';

/// How strict [SeqTracker] should be about `seq` monotonicity.
enum HydraSyncPolicy {
  /// Forward all timed messages as-is (still persist last seq when [store] set).
  none,

  /// Drop timed outputs whose `seq` is less than or equal to the last seen.
  dedupeOnly,

  /// Like [dedupeOnly], and if `seq` jumps by more than 1, fire [onSeqGap]
  /// and optionally trigger a best-effort HTTP snapshot refresh when [http] is set.
  dedupeAndRefreshOnGap,
}

/// Tracks `seq` on [HydraTimedServerOutput] and narrow timed types; supports
/// deduplication after WS history replay and optional gap handling.
class SeqTracker {
  SeqTracker({
    required this.policy,
    HydraStateStore? store,
    HydraHttpClient? http,
    void Function(int lastSeq, int receivedSeq)? onSeqGap,
  })  : _store = store ?? InMemoryHydraStateStore(),
        _http = http,
        _onSeqGap = onSeqGap;

  final HydraSyncPolicy policy;
  final HydraStateStore _store;
  final HydraHttpClient? _http;
  final void Function(int lastSeq, int receivedSeq)? _onSeqGap;

  int? _last;

  /// Load persisted cursor (e.g. after app restart).
  Future<void> restore() async {
    _last = await _store.loadLastSeq();
  }

  int? get lastSeq => _last;

  /// Apply policy; returns `null` if the message should be dropped.
  Future<HydraInboundMessage?> process(HydraInboundMessage message) async {
    final seq = _seqOf(message);
    if (seq == null) {
      return message;
    }

    switch (policy) {
      case HydraSyncPolicy.none:
        _last = seq;
        await _store.saveLastSeq(seq);
        return message;
      case HydraSyncPolicy.dedupeOnly:
      case HydraSyncPolicy.dedupeAndRefreshOnGap:
        if (_last != null && seq <= _last!) {
          return null;
        }
        if (policy == HydraSyncPolicy.dedupeAndRefreshOnGap &&
            _last != null &&
            seq > _last! + 1) {
          _onSeqGap?.call(_last!, seq);
          _refreshSnapshotHint();
        }
        _last = seq;
        await _store.saveLastSeq(seq);
        return message;
    }
  }

  void _refreshSnapshotHint() {
    final h = _http;
    if (h == null) {
      return;
    }
    unawaited(_persistLastSeenBody(h));
  }

  Future<void> _persistLastSeenBody(HydraHttpClient h) async {
    try {
      final r = await h.getSnapshotLastSeen();
      await _store.saveSnapshotHint(r.body);
    } catch (_) {
      // Best-effort only; callers can also poll HTTP explicitly.
    }
  }

  void reset() {
    _last = null;
  }
}

int? _seqOf(HydraInboundMessage m) => switch (m) {
      HydraTimedServerOutput(:final seq) => seq,
      HydraTxValid(:final seq) => seq,
      HydraTxInvalid(:final seq) => seq,
      HydraServerSnapshot(:final seq) => seq,
      _ => null,
    };

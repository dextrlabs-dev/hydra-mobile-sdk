import 'dart:convert';

/// `GET /snapshot/last-seen` — operationId [getSeenSnapshot].
sealed class HydraSeenSnapshot {
  const HydraSeenSnapshot();

  static HydraSeenSnapshot? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final tag = m['tag'] as String?;
      return switch (tag) {
        'NoSeenSnapshot' => const HydraSeenSnapshotNone(),
        'LastSeenSnapshot' => HydraSeenSnapshotLast(
            lastSeen: (m['lastSeen'] as num?)?.toInt() ?? 0,
          ),
        'RequestedSnapshot' => HydraSeenSnapshotRequested(
            lastSeen: (m['lastSeen'] as num?)?.toInt() ?? 0,
            requested: (m['requested'] as num?)?.toInt() ?? 0,
          ),
        'SeenSnapshot' => HydraSeenSnapshotInFlight(raw: m),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

final class HydraSeenSnapshotNone extends HydraSeenSnapshot {
  const HydraSeenSnapshotNone();
}

final class HydraSeenSnapshotLast extends HydraSeenSnapshot {
  HydraSeenSnapshotLast({required this.lastSeen});
  final int lastSeen;
}

final class HydraSeenSnapshotRequested extends HydraSeenSnapshot {
  HydraSeenSnapshotRequested({required this.lastSeen, required this.requested});
  final int lastSeen;
  final int requested;
}

final class HydraSeenSnapshotInFlight extends HydraSeenSnapshot {
  HydraSeenSnapshotInFlight({required this.raw});
  final Map<String, dynamic> raw;
}

/// `GET /snapshot` confirmed snapshot — operationId [getConfirmedSnapshot].
sealed class HydraConfirmedSnapshot {
  const HydraConfirmedSnapshot();

  static HydraConfirmedSnapshot? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final tag = m['tag'] as String?;
      return switch (tag) {
        'InitialSnapshot' => HydraConfirmedInitialSnapshot(
            headId: m['headId'] as String? ?? '',
            initialUTxO: _asStringKeyedMap(m['initialUTxO']),
          ),
        'ConfirmedSnapshot' => HydraConfirmedSnapshotSigned(raw: m),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic>? _asStringKeyedMap(Object? v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

final class HydraConfirmedInitialSnapshot extends HydraConfirmedSnapshot {
  HydraConfirmedInitialSnapshot({required this.headId, this.initialUTxO});
  final String headId;
  final Map<String, dynamic>? initialUTxO;
}

final class HydraConfirmedSnapshotSigned extends HydraConfirmedSnapshot {
  HydraConfirmedSnapshotSigned({required this.raw});
  final Map<String, dynamic> raw;
}

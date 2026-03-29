import 'dart:convert';

/// Parsed `GET /head` payload (Hydra `HeadState` envelope).
///
/// Top-level JSON is `{ "tag": "Idle" | "Open" | ... , "contents"?: { ... } }`.
class HydraHeadState {
  HydraHeadState({required this.tag, this.contents});

  final String tag;
  final Map<String, dynamic>? contents;

  String? get headId => contents?['headId'] as String?;

  List<dynamic>? get pendingCommits {
    final p = contents?['pendingCommits'];
    return p is List<dynamic> ? p : null;
  }

  Map<String, dynamic>? get parameters {
    final p = contents?['parameters'];
    return p is Map<String, dynamic> ? p : p is Map ? Map<String, dynamic>.from(p) : null;
  }

  Map<String, dynamic>? get committed {
    final c = contents?['committed'];
    return c is Map<String, dynamic> ? c : c is Map ? Map<String, dynamic>.from(c) : null;
  }

  /// Parses response body; returns `null` if JSON is not a head envelope.
  static HydraHeadState? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final tag = m['tag'] as String?;
      if (tag == null) return null;
      final raw = m['contents'];
      final contents = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : null;
      return HydraHeadState(tag: tag, contents: contents);
    } catch (_) {
      return null;
    }
  }
}

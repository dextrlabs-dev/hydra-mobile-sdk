/// Persist last-seen `seq` and optional snapshot hints across restarts.
abstract class HydraStateStore {
  Future<int?> loadLastSeq();
  Future<void> saveLastSeq(int seq);
  Future<void> saveSnapshotHint(String json);
  Future<String?> loadSnapshotHint();
}

/// Default in-memory implementation (tests / ephemeral sessions).
class InMemoryHydraStateStore implements HydraStateStore {
  int? _seq;
  String? _hint;

  @override
  Future<int?> loadLastSeq() async => _seq;

  @override
  Future<void> saveLastSeq(int seq) async {
    _seq = seq;
  }

  @override
  Future<void> saveSnapshotHint(String json) async {
    _hint = json;
  }

  @override
  Future<String?> loadSnapshotHint() async => _hint;
}

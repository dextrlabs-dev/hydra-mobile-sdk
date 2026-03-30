import 'package:hydra_client/hydra_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists last Hydra timed `seq` and optional `/snapshot/last-seen` body in the demo app.
class PrefsHydraStateStore implements HydraStateStore {
  PrefsHydraStateStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kSeq = 'hydra_demo_last_seq';
  static const _kHint = 'hydra_demo_snapshot_hint';

  @override
  Future<int?> loadLastSeq() async {
    if (!_prefs.containsKey(_kSeq)) {
      return null;
    }
    return _prefs.getInt(_kSeq);
  }

  @override
  Future<void> saveLastSeq(int seq) async {
    await _prefs.setInt(_kSeq, seq);
  }

  @override
  Future<void> saveSnapshotHint(String json) async {
    await _prefs.setString(_kHint, json);
  }

  @override
  Future<String?> loadSnapshotHint() async => _prefs.getString(_kHint);
}

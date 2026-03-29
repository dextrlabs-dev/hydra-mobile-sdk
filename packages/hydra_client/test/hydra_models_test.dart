import 'dart:io';

import 'package:hydra_client/hydra_client.dart';
import 'package:test/test.dart';

Future<String> _fixture(String name) =>
    File('test/fixtures/$name').readAsString();

void main() {
  test('HydraHeadState parses Idle', () async {
    final h = HydraHeadState.tryParse(await _fixture('head_idle.json'));
    expect(h, isNotNull);
    expect(h!.tag, 'Idle');
    expect(h.contents, isNull);
  });

  test('HydraHeadState parses Initial', () async {
    final h = HydraHeadState.tryParse(await _fixture('head_initial.json'));
    expect(h, isNotNull);
    expect(h!.tag, 'Initial');
    expect(
      h.headId,
      '83d36c9ffb1f8bac1cee31462cf73fdd420be5b37e13b380835d13fc',
    );
    expect(h.pendingCommits, isEmpty);
  });

  test('HydraSeenSnapshot NoSeenSnapshot', () async {
    final s = HydraSeenSnapshot.tryParse(await _fixture('seen_no.json'));
    expect(s, isA<HydraSeenSnapshotNone>());
  });

  test('HydraSeenSnapshot LastSeenSnapshot', () async {
    final s = HydraSeenSnapshot.tryParse(await _fixture('seen_last.json'));
    expect(s, isA<HydraSeenSnapshotLast>());
    expect((s as HydraSeenSnapshotLast).lastSeen, 4);
  });

  test('HydraConfirmedSnapshot InitialSnapshot', () async {
    final s =
        HydraConfirmedSnapshot.tryParse(await _fixture('confirmed_initial.json'));
    expect(s, isA<HydraConfirmedInitialSnapshot>());
    final i = s! as HydraConfirmedInitialSnapshot;
    expect(i.initialUTxO?['aa#0'], isNotNull);
  });

  test('parseHydraUtxoMap', () {
    final m = parseHydraUtxoMap(
      '{"x#0":{"address":"a","value":{"lovelace":1}}}',
    );
    expect(m, isNotNull);
    expect(m!['x#0'], isA<Map<String, dynamic>>());
  });
}

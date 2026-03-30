import 'package:hydra_client/hydra_client.dart';
import 'package:test/test.dart';

void main() {
  test('SeqTracker dedupes replayed seq', () async {
    final store = InMemoryHydraStateStore();
    final t = SeqTracker(
      policy: HydraSyncPolicy.dedupeOnly,
      store: store,
    );
    await t.restore();

    final a = HydraTimedServerOutput(
      tag: 'NetworkConnected',
      seq: 1,
      timestamp: 't',
      json: {},
    );
    final b = HydraTimedServerOutput(
      tag: 'NetworkConnected',
      seq: 1,
      timestamp: 't',
      json: {},
    );
    expect(await t.process(a), same(a));
    expect(await t.process(b), isNull);
    expect(await store.loadLastSeq(), 1);
  });

  test('SeqTracker none forwards duplicates', () async {
    final t = SeqTracker(policy: HydraSyncPolicy.none);
    final a = HydraTimedServerOutput(
      tag: 'X',
      seq: 1,
      timestamp: null,
      json: {},
    );
    expect(await t.process(a), same(a));
    expect(await t.process(a), same(a));
  });

  test('HydraTxValid participates in seq tracking', () async {
    final t = SeqTracker(policy: HydraSyncPolicy.dedupeOnly);
    final v = HydraTxValid(
      seq: 5,
      timestamp: null,
      json: {'transactionId': 'x'},
    );
    expect(await t.process(v), same(v));
    expect(await t.process(v), isNull);
  });
}

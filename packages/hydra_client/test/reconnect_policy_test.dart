import 'package:hydra_client/hydra_client.dart';
import 'package:test/test.dart';

void main() {
  test('HydraReconnectPolicy caps backoff', () {
    const p = HydraReconnectPolicy(
      initialDelay: Duration(milliseconds: 100),
      maxDelay: Duration(seconds: 3),
      backoffMultiplier: 10,
    );
    expect(p.delayForAttempt(0).inMilliseconds, 100);
    expect(p.delayForAttempt(1).inMilliseconds, 1000);
    expect(p.delayForAttempt(2).inMilliseconds, 3000);
    expect(p.delayForAttempt(99).inMilliseconds, 3000);
  });
}

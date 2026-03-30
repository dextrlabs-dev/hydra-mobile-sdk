/// Backoff and behavior for [ReconnectingHydraSession].
class HydraReconnectPolicy {
  const HydraReconnectPolicy({
    this.autoReconnect = true,
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 3),
    this.backoffMultiplier = 2,
  }) : assert(backoffMultiplier >= 1, 'backoffMultiplier must be >= 1');

  /// When false, a socket close stops at [HydraConnectionState.disconnected].
  final bool autoReconnect;

  /// Delay before the first reconnect attempt after a drop.
  final Duration initialDelay;

  /// Upper bound for backoff (Technical Assessment cites ~3s target).
  final Duration maxDelay;

  /// Multiply delay after each failed attempt until [maxDelay].
  final int backoffMultiplier;

  /// Delay used **before** reconnect attempt index [attempt] (0 = first retry).
  Duration delayForAttempt(int attempt) {
    var ms = initialDelay.inMilliseconds;
    final cap = maxDelay.inMilliseconds;
    for (var i = 0; i < attempt; i++) {
      final next = ms * backoffMultiplier;
      ms = next > cap ? cap : next;
    }
    return Duration(milliseconds: ms);
  }
}

/// WebSocket transport lifecycle for `hydra-node` client API.
enum HydraConnectionState {
  /// No socket; not attempting to connect.
  disconnected,

  /// Initial connect or reconnect attempt in flight.
  connecting,

  /// Socket open and receiving frames.
  connected,

  /// Backing off before the next connect attempt.
  reconnecting,
}

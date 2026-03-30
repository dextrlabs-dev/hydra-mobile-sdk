import 'package:catalyst_key_derivation/catalyst_key_derivation.dart';

/// `CatalystKeyDerivation` uses flutter_rust_bridge, which must be initialized once.
class CatalystInitOnce {
  CatalystInitOnce._();

  static Future<void>? _inFlight;

  static Future<void> ensureInitialized() {
    return _inFlight ??= CatalystKeyDerivation.init();
  }
}

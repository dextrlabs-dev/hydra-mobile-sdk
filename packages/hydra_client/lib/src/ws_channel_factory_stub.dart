import 'package:web_socket_channel/web_socket_channel.dart';

/// Fallback when neither `dart:io` nor `dart:html` is available.
WebSocketChannel createHydraWebSocket(Uri uri) {
  throw UnsupportedError(
    'hydra_client WebSocket requires a VM (mobile/desktop) or browser target.',
  );
}

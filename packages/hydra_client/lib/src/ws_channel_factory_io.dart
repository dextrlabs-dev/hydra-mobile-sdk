import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a client WebSocket without using the platform HTTP proxy.
///
/// Android emulators / dev machines often set an HTTP proxy to `127.0.0.1`.
/// `dart:io` then tries to tunnel `ws://your-server` through that proxy; if
/// nothing is listening, you see `Connection refused` on localhost with a random
/// port instead of your hydra-node host.
WebSocketChannel createHydraWebSocket(Uri uri) {
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  return IOWebSocketChannel.connect(uri, customClient: client);
}

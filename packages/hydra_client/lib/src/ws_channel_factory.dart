import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_channel_factory_stub.dart'
    if (dart.library.io) 'ws_channel_factory_io.dart'
    if (dart.library.html) 'ws_channel_factory_html.dart' as impl;

WebSocketChannel createHydraWebSocket(Uri uri) =>
    impl.createHydraWebSocket(uri);

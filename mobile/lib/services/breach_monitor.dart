import 'dart:async';
import 'dart:convert';

import 'socket_client_stub.dart'
    if (dart.library.io) 'socket_client_io.dart'
    as platform;

class BreachMonitor {
  dynamic _socket;
  StreamSubscription<dynamic>? _subscription;
  bool get connected => _socket != null;

  Future<void> connect(
    Uri uri,
    void Function(Map<String, dynamic>) onMessage,
  ) async {
    await disconnect();
    final socket = await platform.openSocket(uri);
    _socket = socket;
    _subscription = (socket as Stream<dynamic>).listen(
      (event) {
        try {
          final decoded = jsonDecode(event.toString());
          if (decoded is Map<String, dynamic>) onMessage(decoded);
        } catch (_) {}
      },
      onDone: () => _socket = null,
      onError: (_) => _socket = null,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
  }
}

import 'dart:io';

Future<dynamic> openSocket(Uri uri) => WebSocket.connect(uri.toString());

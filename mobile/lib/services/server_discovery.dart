import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Finds the PrivacyShield API without the user typing an address: build-time setting, last working
/// server, USB (`adb reverse`), emulator, then every host on the phone's own Wi-Fi subnet.
class ServerDiscovery {
  static const prefsKey = 'server_url';
  static const port = 8000;

  static String? _current;

  static String get baseUrl {
    if (_current != null) return _current!;
    if (ApiConstants.configuredBaseUrl.isNotEmpty) return ApiConstants.configuredBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return ApiConstants.emulatorBaseUrl;
    return ApiConstants.localBaseUrl;
  }

  /// Accepts "192.168.1.5", "192.168.1.5:8000", "http://host:8000/api" and public tunnel URLs such as
  /// "https://name.trycloudflare.com". Port 8000 is only assumed for plain-http local addresses.
  static String normalize(String input) {
    var text = input.trim();
    if (!text.contains('://')) {
      final hostOnly = text.split('/').first;
      final isLocal = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?$').hasMatch(hostOnly) || hostOnly.startsWith('localhost');
      text = '${isLocal ? 'http' : 'https'}://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return input.trim();
    final path = (uri.path.isEmpty || uri.path == '/') ? '/api' : uri.path.replaceAll(RegExp(r'/+$'), '');
    final local = uri.scheme == 'http' && (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(uri.host) || uri.host == 'localhost');
    final authority = uri.hasPort ? '${uri.host}:${uri.port}' : (local ? '${uri.host}:$port' : uri.host);
    return '${uri.scheme}://$authority$path';
  }

  static Future<bool> probe(String base, {Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final res = await http.get(Uri.parse('$base/health')).timeout(timeout);
      return res.statusCode == 200 && res.body.contains('PrivacyShield');
    } catch (_) {
      return false;
    }
  }

  static Future<void> use(String base) async {
    _current = base;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, base);
  }

  static Future<String?> discover({bool includeSaved = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = includeSaved ? prefs.getString(prefsKey) : null;
    final quick = <String>{
      if (ApiConstants.configuredBaseUrl.isNotEmpty) ApiConstants.configuredBaseUrl,
      ?saved,
      ApiConstants.localBaseUrl,
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ApiConstants.emulatorBaseUrl,
    }.toList();

    final found = await firstResponding(quick, timeout: const Duration(milliseconds: 1200)) ??
        await firstResponding(await lanCandidates(), timeout: const Duration(milliseconds: 900));
    if (found != null) await use(found);
    return found;
  }

  static Future<List<String>> lanCandidates() async {
    if (kIsWeb) return const [];
    final hosts = <String>[];
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (addr.isLoopback || parts.length != 4 || addr.address.startsWith('169.254.')) continue;
          final prefix = parts.take(3).join('.');
          for (var i = 1; i < 255; i++) {
            final host = '$prefix.$i';
            if (host != addr.address) hosts.add('http://$host:$port/api');
          }
        }
      }
    } on SocketException {
      return const [];
    }
    return hosts;
  }

  static Future<String?> firstResponding(List<String> bases, {required Duration timeout, int batch = 64}) async {
    for (var i = 0; i < bases.length; i += batch) {
      final slice = bases.sublist(i, min(i + batch, bases.length));
      final results = await Future.wait(slice.map((b) async => await probe(b, timeout: timeout) ? b : null));
      for (final r in results) {
        if (r != null) return r;
      }
    }
    return null;
  }
}

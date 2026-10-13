import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConfigStatus { missing, invalid, ready }

/// Only public client configuration is permitted. This is not an RLS boundary.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey});

  const AppConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final String supabaseUrl;
  final String publishableKey;

  ConfigStatus get status {
    if (supabaseUrl.isEmpty && publishableKey.isEmpty) {
      return ConfigStatus.missing;
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !_isPublicKey(publishableKey)) {
      return ConfigStatus.invalid;
    }
    return ConfigStatus.ready;
  }

  static bool _isPublicKey(String key) {
    if (key.startsWith('sb_publishable_') &&
        key.length > 'sb_publishable_'.length &&
        !RegExp(r'\s').hasMatch(key)) {
      return true;
    }
    // Legacy public anon JWTs remain compatible. Reject administrative roles.
    try {
      final parts = key.split('.');
      if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);

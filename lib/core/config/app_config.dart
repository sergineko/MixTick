import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConfigStatus { missing, invalid, ready }

/// Only public client configuration is permitted. This is not an RLS boundary.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.publishableKey,
    this.allowLocalBackend = false,
  });

  const AppConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      allowLocalBackend = const bool.fromEnvironment(
        'MIXTICK_ALLOW_LOCAL_BACKEND',
      );

  final String supabaseUrl;
  final String publishableKey;
  final bool allowLocalBackend;

  ConfigStatus get status {
    if (supabaseUrl.isEmpty && publishableKey.isEmpty) {
      return ConfigStatus.missing;
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        !(uri.scheme == 'https' ||
            (!kReleaseMode &&
                allowLocalBackend &&
                uri.scheme == 'http' &&
                uri.port == 54321 &&
                {'127.0.0.1', 'localhost', '10.0.2.2'}.contains(uri.host))) ||
        uri.host.isEmpty ||
        (kReleaseMode && (allowLocalBackend || !_productionHost(uri.host))) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !_isPublicKey(publishableKey)) {
      return ConfigStatus.invalid;
    }
    return ConfigStatus.ready;
  }

  /// A public build must use a DNS HTTPS endpoint and no local-development flag.
  /// Syntax validation does not verify the remote project or its permissions.
  bool get publicBuildEligible =>
      status == ConfigStatus.ready &&
      !allowLocalBackend &&
      Uri.parse(supabaseUrl).scheme == 'https' &&
      _productionHost(Uri.parse(supabaseUrl).host);

  static bool _productionHost(String host) =>
      host.contains('.') &&
      host != 'localhost' &&
      !host.endsWith('.localhost') &&
      !host.endsWith('.local') &&
      InternetAddress.tryParse(host) == null;

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

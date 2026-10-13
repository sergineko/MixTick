import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

enum BackendStatus { unconfigured, invalidConfiguration, initialized, failed }

class BackendConnection {
  const BackendConnection.unavailable(this.status) : client = null;
  const BackendConnection.initialized(SupabaseClient this.client)
    : status = BackendStatus.initialized;

  final BackendStatus status;
  final SupabaseClient? client;
}

/// Initialization is not evidence of a successful remote connection.
Future<BackendConnection> initializeSupabase(AppConfig config) async {
  switch (config.status) {
    case ConfigStatus.missing:
      return const BackendConnection.unavailable(BackendStatus.unconfigured);
    case ConfigStatus.invalid:
      return const BackendConnection.unavailable(
        BackendStatus.invalidConfiguration,
      );
    case ConfigStatus.ready:
      try {
        final supabase = await Supabase.initialize(
          url: config.supabaseUrl,
          publishableKey: config.publishableKey,
          debug: false,
        );
        return BackendConnection.initialized(supabase.client);
      } on Exception {
        return const BackendConnection.unavailable(BackendStatus.failed);
      }
  }
}

final backendProvider = Provider<BackendConnection>(
  (ref) => const BackendConnection.unavailable(BackendStatus.unconfigured),
);

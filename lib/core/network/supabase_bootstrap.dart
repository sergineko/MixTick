import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../features/auth/data/secure_auth_storage.dart';
import 'bounded_http_client.dart';

enum BackendStatus { unconfigured, invalidConfiguration, initialized, failed }

class BackendConnection {
  const BackendConnection.unavailable(this.status)
    : client = null,
      authStorage = null;
  const BackendConnection.initialized(
    SupabaseClient this.client, {
    this.authStorage,
  }) : status = BackendStatus.initialized;

  final BackendStatus status;
  final SupabaseClient? client;
  final SecureAuthStorage? authStorage;
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
        final storage = SecureAuthStorage(config.supabaseUrl);
        final supabase = await Supabase.initialize(
          url: config.supabaseUrl,
          publishableKey: config.publishableKey,
          debug: false,
          httpClient: BoundedHttpClient(),
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true,
            detectSessionInUri: false,
            localStorage: storage,
            pkceAsyncStorage: SecurePkceStorage(storage),
          ),
        );
        return BackendConnection.initialized(
          supabase.client,
          authStorage: storage,
        );
      } on Exception {
        return const BackendConnection.unavailable(BackendStatus.failed);
      }
  }
}

final backendProvider = Provider<BackendConnection>(
  (ref) => const BackendConnection.unavailable(BackendStatus.unconfigured),
);

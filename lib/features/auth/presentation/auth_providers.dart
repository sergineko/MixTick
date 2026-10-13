import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/config/app_config.dart';

import '../../../core/network/supabase_bootstrap.dart';
import '../data/supabase_auth_repository.dart';
import '../data/secure_auth_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final backend = ref.watch(backendProvider);
  final client = backend.client;
  if (client == null) return null;
  final storage =
      backend.authStorage ??
      SecureAuthStorage(ref.watch(appConfigProvider).supabaseUrl);
  final repository = SupabaseAuthRepository(
    client,
    stateStorage: SecurePkceStorage(storage),
    localStorage: storage,
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository?.watchSession() ?? Stream<AuthSession?>.value(null);
});

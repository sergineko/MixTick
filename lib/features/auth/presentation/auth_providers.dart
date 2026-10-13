import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_bootstrap.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseAuthRepository(client);
});

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository?.watchSession() ?? Stream<AuthSession?>.value(null);
});

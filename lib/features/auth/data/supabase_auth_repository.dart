import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  AuthSession? _identity(Session? session) {
    if (session == null || session.isExpired) return null;
    return AuthSession(userId: session.user.id);
  }

  @override
  Stream<AuthSession?> watchSession() async* {
    yield _identity(_client.auth.currentSession);
    yield* _client.auth.onAuthStateChange.map(
      (event) => _identity(event.session),
    );
  }
}

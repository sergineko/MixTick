import 'auth_session.dart';

/// Phase 01 observes SDK sessions. Auth operations belong to Phase 03.
abstract interface class AuthRepository {
  Stream<AuthSession?> watchSession();
}

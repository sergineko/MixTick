import 'auth_session.dart';

abstract interface class AuthRepository {
  Stream<AuthSession?> watchSession();
  Future<bool> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> resendConfirmation(String email);
  Future<void> updatePassword(String password);
  Future<void> handleCallback(Uri uri);
  Future<void> validateSession();
  String? get currentEmail;
}

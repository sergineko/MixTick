/// Minimal session identity for navigation; no email or token in presentation.
class AuthSession {
  const AuthSession({required this.userId});
  final String userId;
}

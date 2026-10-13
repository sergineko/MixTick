/// Minimal session identity for navigation; no email or token in presentation.
class AuthSession {
  const AuthSession({
    required this.userId,
    this.requiresPasswordChange = false,
  });
  final String userId;
  final bool requiresPasswordChange;
}

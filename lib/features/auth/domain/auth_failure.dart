enum AuthFailureCode {
  network,
  credentials,
  confirmationRequired,
  weakPassword,
  rateLimited,
  sessionExpired,
  invalidLink,
  unexpected,
  unavailable,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final AuthFailureCode code;
  @override
  String toString() => 'AuthFailure(${code.name})';
}

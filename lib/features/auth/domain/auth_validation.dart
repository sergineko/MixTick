class AuthValidation {
  static String normalizeEmail(String email) => email.trim();
  static bool validEmail(String email) =>
      email.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  // Server policy remains authoritative; the client requires at least 8 chars.
  static bool validPassword(String password) =>
      password.runes.length >= 8 &&
      password.runes.length <= 128 &&
      password.trim().isNotEmpty;
}

class AuthCallback {
  static const redirectUrl = 'es.sergiotech.mixtick://auth/callback';
  static bool valid(Uri uri) =>
      uri.scheme == 'es.sergiotech.mixtick' &&
      uri.host == 'auth' &&
      uri.path == '/callback' &&
      !uri.hasFragment &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      uri.queryParametersAll.length == 1 &&
      uri.queryParametersAll['code']?.length == 1 &&
      RegExp(r'^[a-zA-Z0-9_-]{10,512}$')
          .hasMatch(uri.queryParameters['code'] ?? '');
}

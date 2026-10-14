enum AccountDeletionFailureCode {
  network,
  credentials,
  forbidden,
  invalid,
  unexpected,
}

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.code);
  final AccountDeletionFailureCode code;
}

abstract interface class AccountDeletionRepository {
  /// Acceptance withdraws product data; physical cleanup is server-side.
  Future<void> request(String password, String requestId);
}

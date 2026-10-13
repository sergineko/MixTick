class PublicProfile {
  const PublicProfile({
    required this.username,
    required this.displayName,
    this.avatarPath,
  });
  final String username;
  final String displayName;
  final String? avatarPath;
  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarPath: json['avatar_path'] as String?,
  );
}

class UserProfile extends PublicProfile {
  const UserProfile({
    required this.userId,
    required this.version,
    required super.username,
    required super.displayName,
    super.avatarPath,
  });
  final String userId;
  final int version;
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['user_id'] as String,
    version: json['version'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarPath: json['avatar_path'] as String?,
  );
}

class ProfileValidation {
  static String normalizeUsername(String value) => value.trim().toLowerCase();
  static bool validUsername(String value) =>
      RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(normalizeUsername(value));
  static bool validDisplayName(String value) =>
      value.trim().runes.isNotEmpty && value.trim().runes.length <= 60;
}

enum ProfileFailureCode {
  network,
  usernameTaken,
  conflict,
  forbidden,
  invalidPhoto,
  unexpected,
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.code, {this.diagnosticCode});
  final ProfileFailureCode code;
  final String? diagnosticCode;
  @override
  String toString() => 'ProfileFailure(${code.name}, $diagnosticCode)';
}

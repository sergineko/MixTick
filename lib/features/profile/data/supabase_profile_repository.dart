import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'avatar_processor.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);
  final SupabaseClient _client;
  static const ownColumns = 'user_id,username,display_name,avatar_path,version';
  static const publicColumns = 'username,display_name,avatar_path';
  static const bucket = 'profile-avatars';
  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw const ProfileFailure(ProfileFailureCode.forbidden));
  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      final actor = _userId;
      final result = await operation();
      if (_userId != actor) {
        throw const ProfileFailure(ProfileFailureCode.forbidden);
      }
      return result;
    } on ProfileFailure {
      rethrow;
    } on SocketException {
      throw const ProfileFailure(ProfileFailureCode.network);
    } on http.ClientException {
      throw const ProfileFailure(ProfileFailureCode.network);
    } on TimeoutException {
      throw const ProfileFailure(ProfileFailureCode.network);
    } on PostgrestException catch (e) {
      throw ProfileFailure(switch (e.code) {
        '23505' =>
          e.message.contains('profiles_pkey')
              ? ProfileFailureCode.conflict
              : ProfileFailureCode.usernameTaken,
        '42501' || 'PGRST301' || 'PGRST303' => ProfileFailureCode.forbidden,
        _ => ProfileFailureCode.unexpected,
      }, diagnosticCode: e.code);
    } on StorageException catch (error) {
      throw ProfileFailure(
        ProfileFailureCode.invalidPhoto,
        diagnosticCode: 'storage:${error.statusCode}',
      );
    } catch (error) {
      throw ProfileFailure(
        ProfileFailureCode.unexpected,
        diagnosticCode: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<UserProfile?> loadOwn() => _run(() async {
    final data = await _client
        .from('profiles')
        .select(ownColumns)
        .eq('user_id', _userId)
        .maybeSingle();
    return data == null ? null : UserProfile.fromJson(data);
  });
  @override
  Future<PublicProfile?> loadPublic(String username) => _run(() async {
    if (!ProfileValidation.validUsername(username)) return null;
    final data = await _client
        .from('profiles')
        .select(publicColumns)
        .eq('username', ProfileValidation.normalizeUsername(username))
        .maybeSingle();
    return data == null ? null : PublicProfile.fromJson(data);
  });
  @override
  Future<UserProfile> save({
    required String username,
    required String displayName,
    UserProfile? previous,
    String? avatarPath,
  }) => _run(() async {
    if (!ProfileValidation.validUsername(username) ||
        !ProfileValidation.validDisplayName(displayName)) {
      throw const ProfileFailure(ProfileFailureCode.unexpected);
    }
    final uid = _userId;
    if (previous != null && previous.userId != uid) {
      throw const ProfileFailure(ProfileFailureCode.forbidden);
    }
    final values = {
      'username': ProfileValidation.normalizeUsername(username),
      'display_name': displayName.trim(),
      'avatar_path': avatarPath,
    };
    if (previous == null) {
      // Identity/default and normalization are enforced by PostgreSQL.
      final data = await _client
          .from('profiles')
          .insert(values)
          .select(ownColumns)
          .single();
      return UserProfile.fromJson(data);
    }
    final rows = await _client
        .from('profiles')
        .update(values)
        .eq('user_id', uid)
        .eq('version', previous.version)
        .select(ownColumns);
    // maybeSingle on a mutation can replace SQL errors with HTTP 409/406 in
    // postgrest 2.9.1. Keep the array response to preserve unique-constraint
    // errors and distinguish an actual stale version (zero affected rows).
    if (rows.isEmpty) throw const ProfileFailure(ProfileFailureCode.conflict);
    return UserProfile.fromJson(rows.single);
  });
  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) => _run(() async {
    final actor = _userId;
    final prepared = await prepareAvatar(bytes);
    if (_userId != actor) {
      throw const ProfileFailure(ProfileFailureCode.forbidden);
    }
    const extension = 'jpg';
    final path = '$actor/${_uuid()}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          prepared,
          fileOptions: FileOptions(
            contentType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
            upsert: false,
          ),
        );
    return path;
  });
  @override
  Future<Uint8List> downloadAvatar(String path) =>
      _run(() => _client.storage.from(bucket).download(path));
  @override
  Future<void> removeAvatar(String path) => _run(() async {
    await _client.storage.from(bucket).remove([path]);
  });
}

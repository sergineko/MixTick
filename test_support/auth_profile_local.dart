// Real Flutter/Dart repositories against local Auth/PostgREST/Storage.
// Memory PKCE storage is a test adapter; native encrypted storage has separate
// Android tests. Auth/permissions are real; one marked case injects a transport outage.
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/features/auth/data/supabase_auth_repository.dart';
import 'package:mixtick/features/auth/domain/auth_failure.dart';
import 'package:mixtick/features/auth/domain/auth_validation.dart';
import 'package:mixtick/features/profile/data/supabase_profile_repository.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/profile/domain/profile_repository.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

const endpoint = String.fromEnvironment('SUPABASE_URL');
const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const confirmed = bool.fromEnvironment('MIXTICK_TEST_CONFIRMATION');
final png = img.encodePng(img.Image(width: 8, height: 8));

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }
}

class Actor {
  Actor(this.letter, String suffix)
    : email = 'mixtick-p3-$suffix-$letter@example.test',
      password = 'P3-test-${Random.secure().nextInt(1 << 32)}-safe!',
      username = 'p3_${suffix}_$letter' {
    client = newClient(storage);
    auth = SupabaseAuthRepository(client, stateStorage: storage);
    profile = SupabaseProfileRepository(client);
  }
  final String letter, email, username;
  String password;
  String? id;
  late SupabaseClient client;
  late SupabaseAuthRepository auth;
  late SupabaseProfileRepository profile;
  final storage = MemoryPkceStorage();
}

SupabaseClient newClient(MemoryPkceStorage storage) => SupabaseClient(
  endpoint,
  publicKey,
  httpClient: BoundedHttpClient(),
  authOptions: AuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    autoRefreshToken: false,
    pkceAsyncStorage: storage,
  ),
);
Future<dynamic> jsonRequest(
  String method,
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
}) async {
  if (!{'127.0.0.1', 'localhost'}.contains(uri.host)) {
    throw StateError('Remote request forbidden');
  }
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers?.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode >= 400) {
      throw StateError('Local request failed: HTTP ${response.statusCode}');
    }
    if (text.isEmpty) return null;
    return response.headers.contentType?.mimeType == 'application/json'
        ? jsonDecode(text)
        : text;
  } finally {
    client.close(force: true);
  }
}

final mailIds = <String>{};

class SwitchTransport extends http.BaseClient {
  bool offline = true;
  final delegate = BoundedHttpClient();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) {
      return Future.error(const SocketException('Controlled transport outage'));
    }
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

Future<Uri> mailCallback(String email) async {
  // No email body, action link, code or session token is logged.
  for (var attempt = 0; attempt < 30; attempt++) {
    final inbox = await jsonRequest(
      'GET',
      Uri.parse('http://127.0.0.1:54324/api/v1/messages'),
    ) as Map<String, dynamic>;
    for (final message
        in (inbox['messages'] as List).cast<Map<String, dynamic>>()) {
      if (!jsonEncode(message['To']).contains(email)) continue;
      final id = message['ID'] as String;
      if (mailIds.contains(id)) continue;
      mailIds.add(id);
      final detail = await jsonRequest(
        'GET',
        Uri.parse('http://127.0.0.1:54324/api/v1/message/$id'),
      ) as Map<String, dynamic>;
      final html = (detail['HTML'] as String).replaceAll('&amp;', '&');
      final match = RegExp(r'''href=["']([^"']+/auth/v1/verify[^"']+)["']''')
          .firstMatch(html);
      if (match == null) {
        throw StateError('Confirmation/recovery action missing');
      }
      final action = Uri.parse(match.group(1)!);
      if (!{'127.0.0.1', 'localhost'}.contains(action.host) ||
          action.port != 54321 ||
          action.path != '/auth/v1/verify') {
        throw StateError('Unexpected email action destination');
      }
      final http = HttpClient();
      try {
        final request = await http.getUrl(action);
        request.followRedirects = false;
        final response = await request.close();
        await response.drain<void>();
        final callback = Uri.parse(
          response.headers.value(HttpHeaders.locationHeader) ?? '',
        );
        if (!AuthCallback.valid(callback)) {
          throw StateError(
            'No valid PKCE callback from local email verification',
          );
        }
        return callback;
      } finally {
        http.close(force: true);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('Local fixture email did not arrive');
}

Future<String> fixtureSql(String sql) async {
  final process = await Process.start('docker', [
    'exec',
    '-i',
    'supabase_db_mixtick-phase02',
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-At',
    '-v',
    'ON_ERROR_STOP=1',
  ]);
  process.stdin.write(sql);
  await process.stdin.close();
  final output = utf8.decoder.bind(process.stdout).join();
  final errors = utf8.decoder.bind(process.stderr).join();
  final code = await process.exitCode;
  await errors;
  if (code != 0) throw StateError('Scoped local fixture SQL failed');
  return (await output).trim();
}

void main() {
  if (Uri.tryParse(endpoint)?.host != '127.0.0.1' || publicKey.isEmpty) {
    test(
      'Local integration requires public loopback configuration',
      () {},
      skip: 'Use --dart-define-from-file for the isolated local backend',
    );
    return;
  }
  late Actor a, b;
  late bool signupNeedsConfirmation;
  final actors = <Actor>[];
  final paths = <String>[];
  setUpAll(() async {
    final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
    a = Actor('a', suffix);
    b = Actor('b', suffix);
    actors.addAll([a, b]);
    for (final actor in actors) {
      signupNeedsConfirmation = await actor.auth.signUp(
        actor.email,
        actor.password,
      );
      expect(signupNeedsConfirmation, confirmed);
      if (confirmed) {
        expect(actor.client.auth.currentSession == null, isTrue);
        await expectLater(
          actor.auth.signIn(actor.email, actor.password),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.code,
              'code',
              AuthFailureCode.confirmationRequired,
            ),
          ),
        );
        final callback = await mailCallback(actor.email);
        await actor.auth.handleCallback(callback);
        await expectLater(
          actor.auth.handleCallback(callback),
          throwsA(isA<AuthFailure>()),
        );
      }
      actor.id = actor.client.auth.currentUser!.id;
    }
  });
  tearDownAll(() async {
    if (a.id != null) {
      await a.auth.signIn(a.email, a.password);
      for (final path in paths) {
        await a.profile.removeAvatar(path);
      }
    }
    final ids = actors
        .where((u) => u.id != null)
        .map((u) {
          if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(u.id!)) {
            throw StateError('Invalid fixture identity');
          }
          return "'${u.id}'::uuid";
        })
        .join(',');
    if (ids.isNotEmpty) {
      await fixtureSql('DELETE FROM auth.users WHERE id IN ($ids);');
      for (final actor in actors.where((u) => u.id != null)) {
        await fixtureSql(
          "DELETE FROM private.storage_cleanup_jobs WHERE bucket_id='profile-avatars' AND split_part(object_name,'/',1)='${actor.id}';",
        );
      }
      expect(
        await fixtureSql('SELECT count(*) FROM auth.users WHERE id IN ($ids);'),
        '0',
      );
    }
    if (mailIds.isNotEmpty) {
      await jsonRequest(
        'DELETE',
        Uri.parse('http://127.0.0.1:54324/api/v1/messages'),
        body: {'IDs': mailIds.toList()},
      );
    }
    for (final actor in actors) {
      await actor.auth.dispose();
      await actor.client.dispose();
    }
  });
  test('A01/A11 real signup matches confirmation configuration and authenticated identity', () async {
    expect(signupNeedsConfirmation, confirmed);
    expect((await a.auth.watchSession().first)!.userId, a.id);
    final settings = await jsonRequest(
      'GET',
      Uri.parse('$endpoint/auth/v1/settings'),
      headers: {'apikey': publicKey},
    );
    expect(settings['mailer_autoconfirm'], !confirmed);
  });
  test(
    'A02/A03 real server rejects invalid email and short password',
    () async {
      await expectLater(
        a.auth.signUp('invalid-email', 'Valid-pw-12345!'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        a.auth.signUp(
          'mixtick-p3-invalid-${Random.secure().nextInt(1 << 32)}@example.test',
          'short',
        ),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test('A04 duplicate signup has generic outcome and does not replace current user', () async {
    expect(await a.auth.signUp(a.email, a.password), isTrue);
    expect(a.client.auth.currentUser!.id, a.id);
  });
  test(
    'A05/A06/A07 real login, incorrect password and effective local logout',
    () async {
      await a.auth.signOut();
      expect(a.client.auth.currentSession == null, isTrue);
      await expectLater(
        a.auth.signIn(a.email, 'wrong-password-123'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.credentials,
          ),
        ),
      );
      await a.auth.signIn(a.email, a.password);
      expect(a.client.auth.currentUser!.id, a.id);
    },
  );
  test('P01/P02/P05 real profiles persist, normalize and have minimal public projection', () async {
    final own = await a.profile.save(
      username: ' ${a.username.toUpperCase()} ',
      displayName: 'Autora A',
    );
    await b.profile.save(username: b.username, displayName: 'Autor B');
    expect(own.userId, a.id);
    expect(own.username, a.username);
    final public = await b.profile.loadPublic(a.username);
    expect(public!.displayName, 'Autora A');
    final rows = await b.client
        .from('profiles')
        .select(SupabaseProfileRepository.publicColumns)
        .eq('username', a.username);
    expect(rows.single.keys.toSet(), {
      'username',
      'display_name',
      'avatar_path',
    });
    final edited = await a.profile.save(
      username: own.username,
      displayName: 'Autora editada',
      previous: own,
    );
    expect(edited.version, own.version + 1);
    expect((await a.profile.loadOwn())!.displayName, 'Autora editada');
  });
  test('P03/P04 real duplicate, foreign update and identity spoofing denied by database', () async {
    final before = (await a.profile.loadOwn())!;
    final ownB = (await b.profile.loadOwn())!;
    await expectLater(
      b.profile.save(username: a.username, displayName: 'B', previous: ownB),
      throwsA(
        isA<ProfileFailure>().having(
          (e) => e.code,
          'code',
          ProfileFailureCode.usernameTaken,
        ),
      ),
    );
    final rows = await b.client
        .from('profiles')
        .update({'display_name': 'Impostor'})
        .eq('user_id', a.id!)
        .select('username');
    expect(rows, isEmpty);
    await expectLater(
      b.client.from('profiles').insert({
        'user_id': a.id,
        'username': 'forged_profile',
        'display_name': 'Impostor',
      }),
      throwsA(isA<PostgrestException>()),
    );
    expect((await a.profile.loadOwn())!.displayName, before.displayName);
  });
  test('P06 real private avatar bucket: current public photo, owner writes, foreign path denied', () async {
    final path = await a.profile.uploadAvatar(Uint8List.fromList(png));
    paths.add(path);
    await expectLater(
      b.profile.downloadAvatar(path),
      throwsA(isA<ProfileFailure>()),
    );
    var own = (await a.profile.loadOwn())!;
    own = await a.profile.save(
      username: own.username,
      displayName: own.displayName,
      previous: own,
      avatarPath: path,
    );
    expect(AvatarImage.extension(await b.profile.downloadAvatar(path)), 'jpg');
    final ownB = (await b.profile.loadOwn())!;
    await expectLater(
      b.profile.save(
        username: ownB.username,
        displayName: ownB.displayName,
        previous: ownB,
        avatarPath: path,
      ),
      throwsA(isA<ProfileFailure>()),
    );
    await expectLater(
      b.client.storage
          .from('profile-avatars')
          .uploadBinary(
            '${a.id}/00000000-0000-4000-8000-000000000001.png',
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          ),
      throwsA(isA<StorageException>()),
    );
    await a.profile.save(
      username: own.username,
      displayName: own.displayName,
      previous: own,
      avatarPath: null,
    );
    await expectLater(
      b.profile.downloadAvatar(path),
      throwsA(isA<ProfileFailure>()),
    );
  });
  test(
    'P02/P03 concurrency: one write wins, stale version cannot overwrite',
    () async {
      final before = (await a.profile.loadOwn())!;
      Future<bool> edit(String name) async {
        try {
          await a.profile.save(
            username: before.username,
            displayName: name,
            previous: before,
          );
          return true;
        } on ProfileFailure catch (e) {
          expect(e.code, ProfileFailureCode.conflict);
          return false;
        }
      }

      final results = await Future.wait([edit('Primero'), edit('Segundo')]);
      expect(results.where((r) => r).length, 1);
      expect((await a.profile.loadOwn())!.version, before.version + 1);
    },
  );
  test('A08/I04/I06 real server session recovery and independent users (memory persistence adapter)', () async {
    final serialized = jsonEncode(a.client.auth.currentSession!.toJson());
    final restored = newClient(MemoryPkceStorage());
    final repository = SupabaseAuthRepository(restored);
    try {
      await restored.auth.recoverSession(serialized);
      expect((await repository.watchSession().first)!.userId, a.id);
      expect(
        (await SupabaseProfileRepository(restored).loadOwn())!.username,
        a.username,
      );
      expect((await b.profile.loadOwn())!.userId, b.id);
    } finally {
      await repository.dispose();
      await restored.dispose();
    }
  });
  test('A10 real local recovery email, PKCE return, password update and old password rejection', () async {
    await a.auth.requestPasswordReset(a.email);
    final callback = await mailCallback(a.email);
    final other = newClient(MemoryPkceStorage());
    final otherAuth = SupabaseAuthRepository(other);
    try {
      await expectLater(
        otherAuth.handleCallback(callback),
        throwsA(isA<AuthFailure>()),
      );
    } finally {
      await otherAuth.dispose();
      await other.dispose();
    }
    await a.auth.handleCallback(callback);
    expect((await a.auth.watchSession().first)!.requiresPasswordChange, isTrue);
    final oldPassword = a.password;
    final newPassword = 'Updated-${Random.secure().nextInt(1 << 32)}-safe!';
    await a.auth.updatePassword(newPassword);
    a.password = newPassword;
    expect(
      (await a.auth.watchSession().first)!.requiresPasswordChange,
      isFalse,
    );
    await a.auth.signOut();
    await expectLater(
      a.auth.signIn(a.email, oldPassword),
      throwsA(isA<AuthFailure>()),
    );
    await a.auth.signIn(a.email, newPassword);
  });
  test('I05 session stream survives injected outage and recovers with real server sign-in', () async {
    // Only the outage is injected; session and recovered response come from Auth.
    final transport = SwitchTransport();
    final client = SupabaseClient(
      endpoint,
      publicKey,
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(
      jsonEncode(a.client.auth.currentSession!.toJson()),
    );
    final repository = SupabaseAuthRepository(client);
    final errorSeen = Completer<void>();
    final recovered = Completer<void>();
    final subscription = repository.watchSession().listen(
      (session) {
        if (session?.userId == a.id && !recovered.isCompleted) {
          recovered.complete();
        }
      },
      onError: (Object error) {
        expect(error, isA<AuthFailure>());
        if (!errorSeen.isCompleted) errorSeen.complete();
      },
    );
    try {
      await errorSeen.future.timeout(const Duration(seconds: 40));
      transport.offline = false;
      await repository.signIn(a.email, a.password);
      await recovered.future.timeout(const Duration(seconds: 5));
      expect(client.auth.currentUser!.id, a.id);
    } finally {
      await subscription.cancel();
      await repository.dispose();
      await client.dispose();
      transport.close();
    }
  });
  test(
    'I05 actual refused loopback connection is a typed network failure',
    () async {
      final transport = BoundedHttpClient(
        timeout: const Duration(milliseconds: 500),
      );
      final client = SupabaseClient(
        'http://127.0.0.1:1',
        publicKey,
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repository = SupabaseAuthRepository(client);
      try {
        await expectLater(
          repository.signIn('fixture@example.test', 'Unused-safe-password'),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.code,
              'code',
              AuthFailureCode.network,
            ),
          ),
        );
      } finally {
        await repository.dispose();
        await client.dispose();
        transport.close();
      }
    },
  );
  test(
    'A09 real global revocation rejects refresh and closes restored session',
    () async {
      final revoker = newClient(MemoryPkceStorage());
      try {
        await revoker.auth.signInWithPassword(
          email: a.email,
          password: a.password,
        );
        await revoker.auth.signOut(scope: SignOutScope.global);
        await a.auth.validateSession();
        expect(a.client.auth.currentSession == null, isTrue);
        expect(await a.auth.watchSession().first, isNull);
      } finally {
        await revoker.dispose();
      }
    },
  );
}

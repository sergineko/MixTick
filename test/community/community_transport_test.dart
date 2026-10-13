// Actual loopback sockets, with a test-only actor and HTTP server. Not RLS/Auth.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/community/domain/community.dart';

class TransportOnlyRepository extends SupabaseCommunityRepository {
  const TransportOnlyRepository(super.client);
  @override
  String get actor => 'transport-fixture';
}

void main() {
  for (final headersFirst in [false, true]) {
    test(
      'C03 real socket: obsolete community query aborts ${headersFirst ? "body" : "headers"}',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
            seen = Completer<void>();
        final subscription = server.listen((request) async {
          try {
            await request.drain<void>();
            if (headersFirst) {
              request.response.bufferOutput = false;
              request.response.headers.contentType = ContentType.json;
              request.response.write('[');
              await request.response.flush();
            }
            if (!seen.isCompleted) seen.complete();
            await Future<void>.delayed(const Duration(milliseconds: 350));
            request.response.write(headersFirst ? ']' : '[]');
            await request.response.close();
          } catch (_) {}
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'public-transport-fixture',
          httpClient: BoundedHttpClient(),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        final cancel = CommunityCancellation();
        try {
          final pending = TransportOnlyRepository(client)
              .load(const CommunityQuery(search: 'old'), cancellation: cancel);
          await seen.future.timeout(const Duration(seconds: 5));
          cancel.cancel();
          await expectLater(
            pending,
            throwsA(
              isA<CommunityFailure>().having(
                (e) => e.code,
                'code',
                CommunityFailureCode.network,
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
        } finally {
          await client.dispose();
          await subscription.cancel();
          await server.close(force: true);
        }
      },
    );
  }
}

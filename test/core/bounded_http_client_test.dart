import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mixtick/core/network/bounded_http_client.dart';

void main() {
  for (final headersFirst in [false, true]) {
    test(
      'HTTP real loopback: cancela ${headersFirst ? 'cuerpo' : 'cabeceras'} bloqueado sin devolver respuesta tardía',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          try {
            if (headersFirst) {
              request.response.bufferOutput = false;
              request.response.write('prefix');
              await request.response.flush();
            }
            await Future<void>.delayed(const Duration(milliseconds: 300));
            request.response.write('late response');
            await request.response.close();
          } catch (_) {
            /* Expected when the actual socket request was aborted. */
          }
        });
        final client = BoundedHttpClient(
          timeout: const Duration(milliseconds: 80),
        );
        try {
          await expectLater(
            client.get(Uri.parse('http://127.0.0.1:${server.port}')),
            throwsA(isA<http.RequestAbortedException>()),
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
        } finally {
          client.close();
          await subscription.cancel();
          await server.close(force: true);
        }
      },
    );
  }
}

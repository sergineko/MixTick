import 'package:flutter_test/flutter_test.dart';

import '../../scripts/loopback_docker.dart';

void main() {
  test(
    'Aislamiento: todo puerto TCP/UDP se publica explícitamente en loopback',
    () {
      expect(
        loopbackArguments([
          'create',
          '--name',
          'supabase_db_mixtick-phase02',
          '-p',
          '54322:5432',
          '-p',
          '54324:8025/udp',
          'image',
        ]),
        [
          'create',
          '--name',
          'supabase_db_mixtick-phase02',
          '-p',
          '127.0.0.1:54322:5432',
          '-p',
          '127.0.0.1:54324:8025/udp',
          'image',
        ],
      );
    },
  );
  test('Aislamiento: rechaza publicación implícita, wildcard, abreviaturas y red host', () {
    for (final args in <List<String>>[
      ['run', '-P', 'image'],
      ['run', '--publish-all', 'image'],
      ['create', '-p', '0.0.0.0:54321:8000', 'image'],
      ['run', '-p54321:8000', 'image'],
      ['run', '--publish=54321:8000', 'image'],
      ['run', '--network', 'host', 'image'],
      ['container', 'create', '-p', '54321:8000', 'image'],
    ]) {
      expect(() => loopbackArguments(args), throwsFormatException);
    }
  });
  test('Aislamiento: inspección y comandos sin publicaciones se conservan', () {
    expect(loopbackArguments(['inspect', 'container']), [
      'inspect',
      'container',
    ]);
    expect(
      loopbackArguments(['run', '--network', 'mixtick-local-tests', 'image']),
      ['run', '--network', 'mixtick-local-tests', 'image'],
    );
  });
}

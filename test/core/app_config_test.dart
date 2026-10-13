import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/core/network/supabase_bootstrap.dart';

void main() {
  const url = 'https://test-project.supabase.co';
  AppConfig config(String key, {String endpoint = url}) =>
      AppConfig(supabaseUrl: endpoint, publishableKey: key);

  test('Sin configuración no inicializa ni conecta con Supabase', () async {
    const missing = AppConfig(supabaseUrl: '', publishableKey: '');
    expect(missing.status, ConfigStatus.missing);
    final backend = await initializeSupabase(missing);
    expect(backend.status, BackendStatus.unconfigured);
    expect(backend.client, isNull);
  });

  test('Acepta configuración pública HTTPS sin afirmar conectividad', () {
    expect(config('sb_publishable_test_only').status, ConfigStatus.ready);
  });

  test('Rechaza URL insegura, parcial o con credenciales', () {
    for (final endpoint in [
      '',
      'http://test-project.supabase.co',
      'no-url',
      'https://user:password@test-project.supabase.co',
      'https://test-project.supabase.co?token=value',
      'https://test-project.supabase.co/path',
    ]) {
      expect(
        config('sb_publishable_test_only', endpoint: endpoint).status,
        ConfigStatus.invalid,
        reason: endpoint,
      );
    }
    expect(config('').status, ConfigStatus.invalid);
  });

  test('Rechaza claves administrativas y JWT malformados', () async {
    final adminPayload = base64Url.encode(
      utf8.encode('{"role":"service_role"}'),
    );
    for (final key in [
      'sb_secret_test_only',
      'header.$adminPayload.signature',
      'invalid',
      'a.%%%.b',
      'sb_publishable_',
      'sb_publishable_ with-space',
    ]) {
      final invalid = config(key);
      expect(invalid.status, ConfigStatus.invalid);
      final backend = await initializeSupabase(invalid);
      expect(backend.status, BackendStatus.invalidConfiguration);
      expect(backend.client, isNull);
    }
  });

  test('La clave JWT heredada solo admite el rol público anon', () {
    final payload = base64Url.encode(utf8.encode('{"role":"anon"}'));
    expect(config('header.$payload.signature').status, ConfigStatus.ready);
  });
}

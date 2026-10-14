import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/core/config/app_config.dart';

void main() {
  test(
    'Public-build gate rejects local endpoints, absent config and dev flags',
    () {
      const publicKey = 'sb_publishable_test_only_not_a_connection';
      for (final url in [
        'http://127.0.0.1:54321',
        'https://localhost',
        'https://127.0.0.1',
        'https://10.0.2.2',
        'https://192.168.1.2',
        'https://[::1]',
        'https://host.local',
      ]) {
        expect(
          AppConfig(
            supabaseUrl: url,
            publishableKey: publicKey,
          ).publicBuildEligible,
          false,
        );
      }
      expect(
        const AppConfig(
          supabaseUrl: '',
          publishableKey: '',
        ).publicBuildEligible,
        false,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'https://project.supabase.co',
          publishableKey: publicKey,
          allowLocalBackend: true,
        ).publicBuildEligible,
        false,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'https://project.supabase.co',
          publishableKey: publicKey,
        ).publicBuildEligible,
        true,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'https://project.supabase.co',
          publishableKey: 'sb_secret_test_only',
        ).publicBuildEligible,
        false,
      );
    },
  );
}

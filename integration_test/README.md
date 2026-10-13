# Pruebas de integración — Fase 03

`auth_native_seed_test.dart` y `auth_native_restore_test.dart` ejercitan la UI
real Android, el almacenamiento seguro y la restauración entre procesos, contra
Supabase local aislado. El segundo test recibe el callback del correo real de
Mailpit por Android ACTION_VIEW mediante `scripts/deliver_native_recovery.py`.

Usar `scripts/verify_native_auth.ps1` con el emulador iniciado y el backend
arrancado por `scripts/start_isolated_supabase.ps1`. Es imprescindible
`--no-uninstall` entre ambos procesos. La sesión/fixture temporal se guarda
cifrada en el dispositivo y se retira al finalizar; el runner elimina únicamente
los UUID de cuentas devueltos por la prueba. No usa service_role ni cuentas remotas.

`test_support/auth_profile_local.dart` prueba repositorios Dart contra servicios
reales, en auto-confirmación y confirmación de correo. Su adaptador de PKCE en
memoria se identifica expresamente; un caso híbrido inyecta una caída de
transporte. Las pruebas de UI en `test/auth/` usan repositorios simulados y no
sustituyen RLS ni Auth reales.

Contrato, comandos y límites: [docs/16_AUTH_PROFILE.md](../docs/16_AUTH_PROFILE.md).
iOS necesita macOS/Xcode; no se declara probado en Windows. Los módulos de negocio,
Realtime/CDN y limpieza física siguen pendientes de sus fases/gates de lanzamiento.

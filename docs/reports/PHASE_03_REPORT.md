# Informe final FASE 03

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente `prompts/03_AUTH_PROFILE.md`, integrar
  Auth y perfiles reales con el esquema aceptado, preservar los cuatro módulos,
  los identificadores y las seis migraciones históricas, y resolver el aislamiento
  local antes de ejecutar servicios.
- **Resultado:** **VERIFIED LOCAL** para repositorios Flutter, Auth/PostgREST/
  Storage, RLS, UI y los flujos Android enumerados. **NOT_RUN**: compilación iOS,
  móvil físico y selección interactiva de la galería del sistema. **NOT_VERIFIED**:
  Supabase/correo remoto, CDN, Realtime colaborativo y trabajador de limpieza.
  No se declara la aplicación lista para distribución.
- **Cambios de código:**

| Área | Rutas reales y comportamiento |
|---|---|
| Auth tipada | `lib/features/auth/domain/auth_repository.dart`, `auth_session.dart`, `auth_failure.dart`, `auth_validation.dart`: operaciones reales, identidad sin email/token, validación, retorno exacto |
| Auth/Sesión | `lib/features/auth/data/supabase_auth_repository.dart`, `secure_auth_storage.dart`: PKCE, sesión/verificador seguros, cola de operaciones, recuperación, renovación/validación y salida |
| Estado/navegación | `lib/features/auth/presentation/auth_providers.dart`, `auth_controller.dart`, `auth_lifecycle.dart`, `session_scope.dart`, `lib/app/router.dart`, `lib/app/app.dart`: guards, enlace nativo, errores, protección ante doble envío y cambio de cuenta |
| UI de acceso | `access_page.dart`, `access_status_page.dart`, `auth_form_page.dart`, `confirmation_page.dart`, `auth_link_error_page.dart`, `auth_messages.dart`: bienvenida, login, registro, confirmación, recuperación/actualización y enlace inválido |
| Perfil tipado/real | `lib/features/profile/domain/user_profile.dart`, `profile_repository.dart`, `data/supabase_profile_repository.dart`: creación propia, lectura/edición, username único y versión optimista |
| Perfil/UI/foto | `profile_page.dart`, `profile_edit_page.dart`, `public_profile_page.dart`, `profile_lookup_page.dart`, `profile_providers.dart`, `profile_widgets.dart`, `data/profile_photo_picker.dart`, `avatar_processor.dart`: propio/público, cuenta, foto opcional y reencodificación sin metadatos de origen |
| Configuración/red | `lib/core/config/app_config.dart`, `network/supabase_bootstrap.dart`, `bounded_http_client.dart`: claves públicas, HTTP local explícito solo desarrollo y cancelación real de solicitudes |
| Localización | `lib/app/localization/app_es.arb` y Dart generado: mensajes/validadores/estados en español, fallback `es` y locale `es_ES` |
| Android/iOS | Manifest main/debug, `android/app/src/debug/res/xml/local_network_security.xml`, `ios/Runner/Info.plist`: retorno Auth, backups Android deshabilitados, galería opcional y networking local; IDs intactos |
| Dependencias | `pubspec.yaml`/lock: stack previo conservado; app_links 7.2.2, flutter_secure_storage 11.2.0, image_picker 1.2.2, image 4.12.0, http 1.6.0; integration_test del SDK |
| Tests | `test/auth/`, `test/profile/`, `test/tooling/`, `test/support/`, `test/core/bounded_http_client_test.dart`, `test_support/auth_profile_local.dart`, `integration_test/auth_native_*_test.dart`, `native_test_helpers.dart` |
| Reproducción | `scripts/start_isolated_supabase.ps1`, `assert_local_isolation.ps1`, `loopback_docker.dart`, `verify_auth_profile.ps1`, `verify_native_auth.ps1`, `deliver_native_recovery.py`; runner anterior actualizado para aislamiento y ubicación optativa de evidencias API |

El [inventario completo](phase03/evidence/changed-files.txt) enumera los archivos.
[Comparación de elementos aceptados](phase03/evidence/accepted-phases-diff.txt):
sin cambios en los seis SQL históricos, los cuatro módulos de negocio, temas,
tests Foundation, manifiesto de producto ni informes/evidencias de Fases 01/02.

- **Migraciones/backend:** nueva **20261013000700_profile_avatars.sql**, aplicada
  y después verificada desde cero junto a las anteriores, solo en Docker local
  `mixtick-phase02`. Añade bucket privado de avatares, ruta/existencia/owner,
  políticas y cola de limpieza. No crea tablas públicas nuevas ni RPC Auth.
  Siguen 16 tablas públicas, 3 privadas, 50 ingredientes y 74 alias.
  Auth configura retorno exacto y mínimo local de 8 caracteres; conserva
  auto-confirmación local de Fase 02. Se probó confirmación activada temporalmente
  con Mailpit, restaurando config al finalizar. No hubo link/db push/deploy remoto.

- **Comandos ejecutados:** `<FLUTTER>/<DART>` son los ejecutables instalados en
  `C:\Users\Sergio\develop\flutter\bin`; `<PY>` el Python funcional 3.12.14 del
  runtime documentado; `<CLI>` la CLI portátil 2.120.0. Argumentos, horas y códigos
  se conservan en [calidad final](phase03/evidence/results.json),
  [backend y primer cierre de calidad](phase03/evidence/results-backend-and-initial-quality.json)
  y [Android](phase03/evidence/native-results.json).

| Comando/comprobación | Código final | Resultado y evidencia |
|---|---:|---|
| `start_isolated_supabase.ps1` + `assert_local_isolation.ps1` | 0 | PASS: bindings y listeners 127.0.0.1; 18 intentos por otras interfaces, 0 conexiones. [JSON](phase03/evidence/isolation.json), [contenedores](phase03/evidence/isolated-containers.txt) |
| `<CLI> db reset --local --network-id <NET>` mediante adaptador | 0 | PASS: siete migraciones desde cero. [Salida](phase03/evidence/db-reset.txt) |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 25 checks, dos archivos pgTAP. [Salida](phase03/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: `results: []`. [Salida](phase03/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI> --evidence-dir .../regression-db` | 0 | PASS: 20 regresiones reales A/B/C. [Salida](phase03/evidence/api-regression.txt), [JSON](phase03/evidence/regression-db/api-results.json) |
| `<FLUTTER> test test_support/auth_profile_local.dart --dart-define-from-file=...` | 0 | PASS: 13 escenarios con auto-confirmación local. [Salida](phase03/evidence/auth-local-auto-confirm.txt) |
| Mismo test + `--dart-define=MIXTICK_TEST_CONFIRMATION=true` | 0 | PASS: 13 escenarios con confirmación real activada. [Salida](phase03/evidence/auth-local-email-confirm.txt) |
| Tests `auth_native_seed_test.dart` y `auth_native_restore_test.dart`, `-d emulator-5554 --no-uninstall` | 0 / 0 | PASS: dos procesos Android reales. [Registro](phase03/evidence/native-seed.txt), [restauración](phase03/evidence/native-restore.txt) |
| Ayudante correo local + Android ACTION_VIEW | 0 | PASS: callback real, código no registrado. [Evidencia](phase03/evidence/native-callback-delivery.txt) |
| Lectura/verificación de archivo seguro nativo | 0 | PASS: valores cifrados; sin JWT/email/JSON de sesión en claro. [Evidencia](phase03/evidence/native-encrypted-storage.txt) |
| `<FLUTTER> gen-l10n` | 0 | PASS. [Salida](phase03/evidence/gen-l10n.txt) |
| `<FLUTTER> analyze` | 0 | PASS: sin incidencias. [Salida](phase03/evidence/flutter-analyze.txt) |
| `<FLUTTER> test --reporter expanded` | 0 | PASS: 48 tests. [Salida](phase03/evidence/flutter-test.txt) |
| `<DART> format --output=none --set-exit-if-changed lib test test_support integration_test scripts/loopback_docker.dart` | 0 | PASS: sin cambios. [Salida](phase03/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: paquete, applicationId, namespace, MainActivity y 3 configuraciones iOS. [Salida](phase03/evidence/identifiers.txt) |
| `<FLUTTER> build apk --debug` | 0 | PASS: APK de app; no publicación. [Salida](phase03/evidence/android-debug-build.txt), [identidad](phase03/evidence/apk-identity.txt), [SHA256](phase03/evidence/apk-sha256.json) |
| Auditoría SQL y parada exclusiva local | 0 | PASS: fixtures/objetos/colas cero y stack apagado. [Auditoría](phase03/evidence/database-audit.json), [parada](phase03/evidence/local-stop-verification.txt) |
| Compilar/firmar/ejecutar iOS | — | NOT_RUN: Windows, sin macOS/Xcode |
| Móvil físico / galería del sistema mediante interacción | — | NOT_RUN: no ejecutado; no sustituir por tests de bytes/UI |

El primer runner combinado terminó con código **1** porque analyze tenía avisos
de estilo, después de completar todos los checks backend con código 0. Se preserva
ese JSON con su FAIL. Los avisos se corrigieron y el runner final de calidad
terminó con código 0. Los fallos iniciales no se presentan como pruebas PASS.
Flutter 3.47.7/Dart 3.13.5 conservados; dependencias adicionales compatibles según
sus manifiestos oficiales y la resolución/build ejecutados. Android probado en
emulador Pixel_10a, sistema Android 17/API 37, registrado en
[dispositivo](phase03/evidence/android-emulator.json).

- **Pruebas:** 48 locales (incluyen las 21 Foundation), 25 SQL, 20 API anteriores,
  13 escenarios de cliente en cada modo de correo y dos pruebas nativas.
  Los repositorios simulados se usan solo en pruebas de widgets. La suite cliente
  usa Auth/API/Storage reales y almacenamiento PKCE en memoria; uno de sus 13
  casos es híbrido: inyecta una caída y vuelve a un sign-in de servidor real.
  Otro prueba un socket loopback rechazado. No se cuentan esos dos como RLS.

| Caso solicitado | Estado | Alcance comprobado |
|---|---|---|
| A01 registro | PASS | Auth real en ambos modos y registro UI Android |
| A02 email inválido | PASS | Validación UI/cliente y rechazo real de Auth |
| A03 contraseña inválida | PASS | Longitud/repetición local y rechazo server |
| A04 email repetido | PASS | Resultado/mensaje genérico; no reemplaza identidad actual |
| A05 login correcto | PASS | Sesión de Auth real y UI Android |
| A06 contraseña incorrecta | PASS | Rechazo real y mensaje genérico comprensible |
| A07 logout | PASS | SDK sin sesión y almacenamiento nativo eliminado |
| A08 restauración al reiniciar | PASS Android | Segundo APK/proceso lee sesión cifrada y valida/renueva en servidor |
| A09 sesión revocada | PASS | Logout global independiente; refresh rechazado y sesión cerrada |
| A10 recuperación | PASS | Correo Mailpit real, PKCE, dispositivo incorrecto/replay rechazados, cambio y contraseña vieja denegada; ACTION_VIEW Android |
| A11 confirmación email | PASS local | Sin sesión antes de confirmar; login denegado; verificación y retorno PKCE reales |
| P01 crear/recuperar | PASS | FK/default auth.uid real, datos persistentes y username normalizado |
| P02 edición propia | PASS | UPDATE autorizado y versión; dos escrituras concurrentes no sobrescriben silenciosamente |
| P03 nombre repetido | PASS | Restricción SQL y error localizado; normalización ASCII conforme a BD |
| P04 edición/suplantación ajenas | PASS | API directa: cero filas editadas; INSERT con user_id ajeno denegado |
| P05 perfil público mínimo | PASS | Proyección real de tres campos y UI sin email/UUID/metadata/versiones |
| P06 foto opcional | PASS servidor/cliente | Subida/lectura real, privacidad por referencia, owner/path, retirada y reencodificación; picker nativo interactivo NOT_RUN |
| I01 rutas sin sesión | PASS | Guards, carga/error y accesos directos en Foundation/UI |
| I02 cuatro pestañas | PASS | Navegación Foundation + sesión real Android; no quinta pestaña |
| I03 volver al acceso | PASS | Logout UI Android y widgets |
| I04 aislamiento entre usuarios | PASS | Clientes reales A/B y RLS; descarte de borrador al cambiar cuenta probado con mock |
| I05 conectividad | PASS | Socket real rechazado, abort de cabeceras/cuerpo real y caso híbrido identificado |
| I06 persistencia | PASS | Perfil y sesión recuperados por un segundo proceso Android |
| I07 regresiones | PASS | 21 tests Foundation, 20 escenarios API anteriores y comparación de elementos aceptados |

- **Seguridad:** RLS conserva autoridad de identidad/edición; no hay service_role
  ni secret keys en Flutter. Los perfiles no incorporan email/metadata de Auth;
  el DTO público es mínimo. Storage rechaza rutas ajenas/referencias suplantadas
  y lecturas de fotos no activas. Se evitan callbacks arbitrarios, registro de
  códigos/tokens y sesiones tardías tras timeout/cambio de cuenta. Las pruebas
  de producto usan claves públicas/JWT de usuarios reales; postgres local solo
  para migraciones, introspección y limpieza de fixtures. [Contrato](../16_AUTH_PROFILE.md).

**Limpieza e aislamiento:** auditoría final: 0 usuarios Auth, perfiles, recetas,
listas, fotos de recetas/avatares, jobs y ledger de pruebas. Correos de fixtures
retirados por IDs coincidentes; no se borró correo de otros destinatarios.
Solo `mixtick-phase02` se apaga y no conserva puertos publicados. Docker global,
firewall y otros proyectos no se modificaron.

- **Problemas encontrados y correcciones:**

| Problema real | Resultado |
|---|---|
| CLI heredada publicaba en todas las interfaces | Adaptador de proceso antes de creación; pruebas de argumentos, bindings/listeners/probes reales. No daemon proxy ni confianza basada solo en URL localhost |
| Adaptador recibía más de una ruta Docker | Get-Command devolvía exe y wrapper; selección única y ruta compilada en adaptador. Primeros arranques fallaron sin dejar servicios |
| Router perdía ruta durante carga / se recreaba al cambiar identidad | Ruta pendiente conservada; router estable y SessionScope en formularios. Tests negativos iniciales y finales preservados |
| PostgREST maybeSingle en mutación ocultaba SQLSTATE / cero filas | Respuesta en array; errores de unicidad y conflicto reales verificados |
| Transporte cancelable bloqueaba body / perdía boundary multipart | Bombeo y envío concurrentes; copiar headers tras finalize. Sockets y subidas reales finales PASS |
| Fixture PNG antigua no decodificaba correctamente | Fixture válida generada por encoder; no se relajó validación de imagen |
| Prueba híbrida asumía menos tiempo que los retries del SDK | Plazo de prueba ajustado al comportamiento observado; stream vuelve a emitir identidad real tras el fallo |
| Mailpit DELETE por mensaje no admitido / respuesta no JSON | Borrado selectivo por IDs y manejo de respuesta; limpieza verificada |
| Flutter test desinstalaba entre procesos | --no-uninstall, sin sustituir la restauración por un mock |
| Marcador nativo de fixture anterior permanecía | Limpieza del marcador reservada a email/UUID de tests, validación de identidad, espera/readback; no borrado global de datos de app |
| Avisos analyze/sintaxis/estilo | Corregidos; FAIL iniciales preservados, análisis final sin incidencias |
| Gradle/JDK/XML SDK | Advertencias heredadas; builds debug y ejecuciones Android finalizaron, sin afirmar entorno sin advertencias |

- **Limitaciones y riesgos:** la renovación detecta revocación al consultar Auth;
  JWT ya emitidos conservan su semántica hasta expirar. No se afirma revocación
  instantánea por RLS. El límite HTTP es por intento; el SDK puede reintentar.
  Correo remoto y retornos iOS requieren sus entornos reales. No hay asociación
  Universal Links remota ni configuración de proyecto remoto creada. El selector
  nativo de fotos necesita QA de interacción en Android/iOS. No se implementan
  trabajador físico de imágenes, Realtime/CDN, moderación operativa ni eliminación
  completa de cuenta; se conservan como requisitos previos al lanzamiento.
- **Archivos de documentación actualizados:** README raíz/backend, PROGRESS,
  decisiones, Storage, integración, `docs/16_AUTH_PROFILE.md`, ADR-017 y este
  informe/evidencias. Informes históricos intactos.
- **Decisiones nuevas/ADR:** [ADR-017](../adr/017_AUTH_PROFILE.md): onboarding
  explícito, sesión/verificador seguros, PKCE, perfil mínimo, versión, avatar
  privado y pruebas locales efectivamente aisladas.
- **Pendientes para la siguiente fase:** solo tras revisión y autorización,
  Fase 04 (Mi recetario) sobre el esquema aceptado. Cerrar los gates anteriores
  antes de distribución; no desarrollarlos automáticamente fuera de alcance.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene para revisión. No se hicieron
  commits/push, despliegues, publicaciones ni cambios de Supabase remoto.
  HEAD permanece `143158444c1a3f15c0914862e93780401b857f59`.

## Autorización posterior de GitHub

El 2026-10-13, después del cierre descrito en este informe, el propietario
solicitó «Realiza push del estado actual del proyecto». Esta autorización permite
crear el commit y subir el estado de Fase 03 a `sergineko/MixTick`, rama `main`.
No autoriza Fase 04, despliegues ni cambios de Supabase remoto. Los resultados
y restricciones anteriores describen el momento de cierre de la implementación.

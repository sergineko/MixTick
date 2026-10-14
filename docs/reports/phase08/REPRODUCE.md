# Reproducción de Fase 08

Windows/PowerShell 7, Flutter 3.47.7, Dart 3.13.5, Python 3.12.14,
Supabase CLI 2.120.0, Docker 29.8.1 y SDK Android del host. Versiones de paquetes
en `pubspec.lock`, sin cambios de dependencias. Paths de ejecutables por defecto
en los scripts; parametrizables cuando se indica. La carpeta `.tooling` está
ignorada y no debe publicarse.

## Regresiones y calidad

```powershell
scripts/verify_release.ps1
scripts/verify_release.ps1 -BackendChecks -BackendOnly -ResetLocal
```

El segundo comando requiere el proyecto dedicado `mixtick-phase02`, sin cuentas
ajenas/fixtures anteriores. Inicia exclusivamente servicios del proyecto con
puertos explícitos 127.0.0.1, aplica las 15 migraciones desde cero, ejecuta SQL,
lint, API y suites Dart reales; prueba ambos modos de confirmación y restaura
configuración/para su stack. No reescribir evidencias históricas 01–07.
Los archivos de salida Fase08 se pueden conservar en una copia de carpeta antes
de repetir para mantener el historial de fallos. No ejecutar reset remoto.

## Worker, cuenta y moderación

Reiniciar con `scripts/start_isolated_supabase.ps1 -EvidenceDirectory
docs/reports/phase08/evidence` y en otra terminal ejecutar
`scripts/serve_release_functions.ps1`. La función de borrado conserva JWT; el
worker exige su secreto servidor. No usar flags globales que desactiven Auth.
El secreto se genera localmente en el archivo ignorado, sin imprimirlo.

```powershell
python scripts/test_release_operations.py --label un-nombre-nuevo
```

Usar el Python real instalado, no el alias de Windows Store si no funciona.
La suite exige cero cuentas y crea solo sus fixtures aleatorios. Detiene y
reinicia exclusivamente los contenedores Auth/Storage del proyecto para probar
interrupciones; no ejecutar junto a otra suite ni en un entorno compartido.
`finally` restaura servicios y limpia solo identidades registradas/validadas.
La consola de moderación se prueba con un JWT ordinario autorizado mediante
tabla privada, no con service_role. El teardown administrativo se identifica
separadamente y no se atribuye al producto.

Para el E2E, crear `.tooling/phase08-client.local.json` con URL loopback,
clave pública local obtenida sin mostrar secretos y flag local true. Ejecutar:

```powershell
flutter test test_support/release_e2e_local.dart --dart-define-from-file=.tooling/phase08-client.local.json --reporter expanded
python scripts/cleanup_release_fixtures.py --fixtures .tooling/phase08-e2e-fixtures.json
```

La segunda instrucción es teardown del host incluso si falla el E2E; no demuestra
borrado de usuario. El test usa repositorios reales, cuentas GoTrue y sockets
independientes; el disparo del worker se hace desde un proceso Python del host,
sin introducir secreto en Dart móvil. La prueba de controller controla únicamente
el provider de UID: el repositorio, red y permisos son reales. Se generan también
20 muestras de HTTP/parseo por operación, con calentamiento excluido.

## Benchmark de matching

`scripts/benchmark_release_matching.py --label <nuevo> --samples 30` utiliza el
prefijo de fixtures original, EXPLAIN ANALYZE BUFFERS, mismo rol/UID y RLS. Cada
ejecución tiene 2 calentamientos por modo y hace rollback. La medición anterior
se obtuvo antes de aplicar 012; no modificar migraciones aplicadas para repetirla.
Para comparar desde otro checkout, usar una BD local desechable con 001–011.
No ejecutar un downgrade sobre datos existentes. Las evidencias before/after
conservadas permiten revisar planes, muestras y hashes sin volver atrás.

## Android

Iniciar AVD Pixel_10a de manera oculta; verificar que es el emulador propio y
usar `emulator-5554`. Backend local con auto-confirmación; funciones servidas
para el test de cuenta. Ejecutar secuencialmente:

```powershell
scripts/verify_release_native_auth.ps1
scripts/verify_native_recipes.ps1 -EvidenceDirectory docs/reports/phase08/recipe-regression/evidence
scripts/verify_release_native_community.ps1
scripts/verify_release_native_matching.ps1
scripts/verify_release_native_shopping.ps1
scripts/verify_release_native_account.ps1
```

El test original de galería requiere una imagen PNG controlada en
`.tooling/phase04-gallery.png`; generar con `scripts/prepare_release_gallery.py`
si falta. Los adaptadores nuevos cambian únicamente destinos de evidencia,
configuraciones ignoradas y helpers de captura; las aserciones originales no
se editan. Cada runner restaura modo nocturno y retira solo sus fixtures. Las
capturas son del emulador real, no diseños generados. No hay dos Android físicos.

Al terminar, producir APK estándar debug de `lib/main.dart` y APK release unsigned:

```powershell
flutter build apk --debug
flutter build apk --release
```

Validar IDs/manifest/hash y estado de firma del artefacto. No reutilizar el APK
de integración como distribución. Sin configuración pública autorizada, la app
muestra configuración pendiente y no acredita conexión a ningún proyecto.

Inspección final de esquema/fixtures: `scripts/audit_release_database.sql`,
solo SQL local del host. Detener solo los procesos/servicios iniciados para la
auditoría, verificando sus identidades; no parar Docker global ni otras apps.
No hacer stage, commit, push, firma real, despliegue o publicación.

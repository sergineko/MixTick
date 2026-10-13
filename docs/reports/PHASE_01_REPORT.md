# Informe final FASE 01

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente Foundation: generar Flutter Android/iOS,
  respetar los identificadores aprobados y preparar arquitectura modular,
  navegación protegida, diseño inicial y configuración pública de Supabase.
- **Resultado:** **VERIFIED** para la implementación y las comprobaciones locales
  de Foundation enumeradas a continuación. APK Android compilado. Compilación
  iOS y pruebas en dispositivos **NOT_RUN**; ninguna conexión real a Supabase
  verificada. Los módulos y el acceso real permanecen pendientes de sus fases.
- **Cambios de código:** proyecto creado en esta carpeta con
  `flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .`.
  Se generaron 74 archivos de esqueleto, sin sobrescribir la documentación de
  arranque. Después se sustituyó el contador de ejemplo por la base modular.

| Área | Rutas reales creadas o modificadas | Resultado |
|---|---|---|
| Entrada y dependencias | `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.metadata`, `.gitignore` | Bootstrap opcional, Riverpod y dependencias compatibles; exclusión de configuración local |
| Aplicación y navegación | `lib/app/app.dart`, `lib/app/router.dart`, `lib/app/app_shell.dart`, `lib/shared/models/app_module.dart` | Cuatro pestañas, router estable y guards; perfil fuera de la barra |
| Diseño y localización | `lib/app/theme/app_theme.dart`, `l10n.yaml`, `lib/app/localization/app_es.arb`, `lib/app/localization/app_es_ES.arb`, `lib/app/localization/generated/app_localizations.dart`, `lib/app/localization/generated/app_localizations_es.dart` | Material 3, claro/oscuro, español de España con fallback `es` y textos localizables |
| Configuración y estados | `lib/core/config/app_config.dart`, `lib/core/network/supabase_bootstrap.dart`, `lib/core/errors/app_failure.dart`, `lib/core/widgets/app_states.dart`, `config/supabase.example.json` | Variables públicas, rechazo de roles administrativos y estados reutilizables |
| Auth | `lib/features/auth/domain/auth_repository.dart`, `lib/features/auth/domain/auth_session.dart`, `lib/features/auth/data/supabase_auth_repository.dart`, `lib/features/auth/presentation/auth_providers.dart`, `lib/features/auth/presentation/access_page.dart`, `lib/features/auth/presentation/access_status_page.dart`, `lib/features/auth/presentation/session_page.dart` | Observación tipada de sesión; acceso informativo sin login ni bypass ficticio |
| Cuatro módulos | `lib/features/community/presentation/community_page.dart`, `lib/features/recipes/presentation/recipes_page.dart`, `lib/features/cook_today/presentation/cook_today_page.dart`, `lib/features/shopping/presentation/shopping_page.dart`, `lib/shared/widgets/feature_placeholder.dart` | Pantallas «Próximamente» sin datos ni consultas simuladas |
| Perfil de soporte | `lib/features/profile/presentation/profile_page.dart` | Ruta protegida con retorno al shell |
| Android | `android/app/build.gradle.kts`, `android/app/src/main/kotlin/es/sergiotech/mixtick/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, esqueleto Gradle y recursos generados | Identificadores fijos, nombre visible MixTick y permiso INTERNET |
| iOS | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, esqueleto Runner/RunnerTests, Flutter y recursos generados | Tres configuraciones Runner con ID aprobado; nombre visible MixTick |
| Verificación | `test/app/foundation_test.dart`, `test/core/app_config_test.dart`, `scripts/verify_foundation.ps1` | 21 tests y evidencias reproducibles; eliminado `test/widget_test.dart` del contador de ejemplo |
| Estructura futura | `.gitkeep` en `data/` y `domain/` sin implementación, `lib/core/utils/`, `assets/images/`, `assets/icons/`, `supabase/migrations/`, `supabase/tests/`; `supabase/README.md`, `supabase/seed.sql`, `integration_test/README.md` | Directorios reservados sin CRUD ni esquema SQL |

El [inventario de archivos](evidence/phase01-files.txt) incluye también los
documentos originales y excluye cachés y binarios de compilación.

- **Migraciones/backend:** ninguna migración creada o ejecutada. `seed.sql`
  contiene exclusivamente comentarios. No se provisionaron proyectos, tablas,
  políticas, RPC, buckets, cuentas ni datos en Supabase. No se añadieron claves
  reales. El cliente solo se inicializa si hay configuración pública válida;
  inicialización no equivale a conexión remota verificada.
- **Comandos ejecutados:** resultados finales verificables en la tabla. Todos
  se ejecutaron desde la raíz de MixTick. Las rutas exactas de ejecutables,
  argumentos y códigos están en [results.json](evidence/results.json). El script
  completo conserva el último resultado de cada comprobación; el análisis se
  repitió tras eliminar un import redundante.

| Comando | Código de salida | Estado | Salida/evidencia |
|---|---:|---|---|
| `flutter --version` | 0 | PASS | Flutter 3.47.7 estable, revisión `abaf9c5237`; [salida](evidence/flutter-version.txt) |
| `dart --version` | 0 | PASS | Dart 3.13.5 estable; [salida](evidence/dart-version.txt) |
| `flutter doctor -v` | 0 | PASS (ejecución) | Diagnóstico con advertencias Android y Windows desktop; [salida completa](evidence/flutter-doctor.txt). No significa entorno sin incidencias |
| `flutter create --org es.sergiotech --project-name mixtick --platforms=android,ios .` | 0 | PASS | `Wrote 74 files.`; identidad comprobada inmediatamente después de generar |
| `flutter pub get` | 0 | PASS | Resolución efectiva de Riverpod 3.4.3, GoRouter 18.0.2, Supabase Flutter 2.18.3 e intl 0.20.3; [salida](evidence/pub-get.txt) |
| `flutter gen-l10n` | 0 | PASS | Generación con `es` y `es_ES`; [salida](evidence/gen-l10n.txt) |
| `dart format lib test` | 0 | PASS | 27 archivos, 0 cambios en la última ejecución; [salida](evidence/format.txt) |
| `dart format --output=none --set-exit-if-changed lib test` | 0 | PASS | 27 archivos, 0 cambios; [salida](evidence/format-check.txt) |
| `flutter analyze` | 0 | PASS | `No issues found! (ran in 8.3s)`; [salida final](evidence/analyze.txt) |
| `flutter test --reporter expanded` | 0 | PASS | `+21: All tests passed!`; [salida](evidence/test.txt) |
| Python funcional: `scripts/check_identifiers.py --strict` | 0 | PASS | 5 comprobaciones; 3 coincidencias Runner iOS; [salida](evidence/identifiers.txt) |
| `flutter build apk --debug` | 0 | PASS | `Built build\app\outputs\flutter-apk\app-debug.apk`; [salida](evidence/android-debug-build.txt) |
| `flutter test --reporter expanded --dart-define=CAPTURE_FOUNDATION_PREVIEWS=true` | 0 | PASS | 21 tests; 10 renders claros/oscuros de acceso y cuatro módulos; [salida](evidence/test-previews.txt) |
| `aapt dump badging build/app/outputs/flutter-apk/app-debug.apk` | 0 | PASS | Paquete `es.sergiotech.mixtick`, etiqueta `MixTick`, actividad `es.sergiotech.mixtick.MainActivity`; [salida](evidence/apk-identity.txt) |
| Compilar/firmar/ejecutar iOS | — | NOT_RUN | Windows, sin macOS/Xcode; no se ejecutó un comando imposible en este entorno |
| Ejecutar app en teléfono o emulador Android | — | NOT_RUN | No había dispositivo Android activo; la compilación y los renders no sustituyen esta prueba |

El verificador se ejecutó con el Python 3.12.14 funcional del runtime de Codex:

```powershell
& 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts/check_identifiers.py --strict
```

Los aliases `python` y `py` del sistema apuntaban a WindowsApps y no se podían
ejecutar. Su uso es **NOT_RUN**; no impidió ejecutar el script con Python real.

Para repetir la batería con el SDK instalado:

```powershell
.\scripts\verify_foundation.ps1 -FlutterExecutable 'C:\Users\Sergio\develop\flutter\bin\flutter.bat' -DartExecutable 'C:\Users\Sergio\develop\flutter\bin\dart.bat' -PythonExecutable 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -IncludeAndroidBuild
```

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`, 166.911.265 bytes.
SHA256: `4708e9e807e53a9f085cbdc6b8b354382c9c5e2f994a9d2625fa8ed596bc8686`.
[Hash calculado del archivo](evidence/apk-sha256.txt).

- **Pruebas:** 21 casos (16 de widgets y 5 de configuración), todos PASS en la
  ejecución final. Las identidades controladas están exclusivamente en tests.

| Caso | Estado | Alcance comprobado |
|---|---|---|
| Navegación | PASS | Exactamente cuatro destinos, cambio entre ellos, perfil transversal y retorno |
| Rutas sin sesión | PASS | Acceso directo bloqueado a las cuatro pestañas y `/profile` (5 casos) |
| Carga/error/cambio de sesión | PASS | No mostrar contenido protegido mientras carga o falla; entrada y salida del shell al cambiar el stream (3 casos) |
| Configuración ausente | PASS | Aviso comprensible, consulta de estado y regreso al acceso; no se crea cliente Supabase |
| Interfaz y localización | PASS | `es_ES`, claro/oscuro, acceso y cuatro pestañas con texto al 200 % en 320×640; render móvil en 390×844 (6 casos de widgets) |
| Configuración pública | PASS | Rechazo de URL insegura/parcial/con credenciales, secret keys y JWT administrativos o malformados; aceptación sintáctica de publishable/anon (5 casos de configuración) |
| A01/A02 completos | NOT_RUN | Registro, validación, login, logout y recuperación reales pertenecen a Fase 03. Solo se probó el subcaso local de guards |
| R01–R05, C01–C04, M01–M06, S01–S08, X01/X03 | NOT_RUN | CRUD, matching, compra, moderación y eliminación de cuenta quedan fuera de Foundation |
| X02 (analyze/test/IDs) | PASS | Comprobaciones locales enlazadas; migraciones y RLS no verificadas todavía |

Se inspeccionaron visualmente los renders de acceso claro, recetario oscuro y
compra clara: textos, iconos, navegación y disposición coherentes. Son renders
de Flutter Test, no capturas de móvil ni evidencia de autenticación externa.
Ejemplos: [acceso claro](previews/access-light.png),
[recetario oscuro](previews/recipes-dark.png), [compra clara](previews/shopping-light.png).

- **Seguridad:** guards cerrados ante ausencia, carga y error de sesión.
  Configuración administrativa rechazada antes del bootstrap. No se utilizan
  tokens ni usuarios de demostración en el cliente. No se leen ni escriben
  recetas, relaciones o fotografías. **RLS/Storage/Realtime multiusuario:
  NOT_RUN**, porque aún no hay backend; deben verificarse con usuarios reales
  de pruebas y permisos del servidor en sus fases. Los guards no sustituyen RLS.
- **Limitaciones y riesgos:**

| Incidencia encontrada | Tratamiento/estado final |
|---|---|
| Flutter/Dart ausentes | Resuelta con instalación explícitamente autorizada en `C:\Users\Sergio\develop\flutter`; PATH de usuario verificado. Nuevas terminales reciben el PATH; procesos abiertos antes pueden necesitar reinicio |
| Descarga inicial de metadatos con ruta incorrecta | La URL inicial devolvió `NoSuchKey`; se corrigió al endpoint oficial y se verificó SHA256 antes de instalar |
| SDK descargado | Flutter 3.47.7 + Dart 3.13.5; SHA256 oficial `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`; archivo temporal de instalación eliminado tras instalar |
| Dos tests no desplazaban el acceso antes de pulsar | Fallo inicial preservado en [test-initial.txt](evidence/test-initial.txt). Corregidos con desplazamiento real y taps fallidos tratados como error; ejecución final PASS |
| Variante `es_ES` sin fallback `es` | Flutter rechazó la generación y dos assertions detectaron locale genérico. Se añadieron recurso base y variante; ejecución final comprueba `es` y país `ES`. [Ejecución intermedia](evidence/test-previews-initial.txt) |
| Import redundante de `dart:typed_data` | Aviso del analizador preservado en [analyze-initial.txt](evidence/analyze-initial.txt); retirado; análisis final sin incidencias |
| Fuentes de iconos ausentes en renders iniciales | Se cargaron fuentes Roboto y MaterialIcons del SDK solo para capturas optativas de tests; renders finales revisados |
| Licencias Android pendientes en doctor | Persisten algunas advertencias. No se aceptaron acuerdos adicionales; la compilación debug sí terminó correctamente |
| Gradle/JDK | Advertencia de acceso nativo restringido con JDK 25; primera compilación también avisó de versiones XML del SDK. No impidieron compilar; salida final conservada |
| Visual Studio ausente | Afecta solo a Windows desktop, plataforma fuera de este proyecto; no bloquea Android/iOS fuente |
| Credenciales/backend ausentes | Estado previsto para Foundation; no se inventó conexión. Login y todos los módulos de negocio pendientes |
| Distribución | Iconos de lanzamiento Flutter provisionales, APK debug y firma de distribución sin preparar. Compilación iOS, dispositivos y auditoría de accesibilidad completa pendientes |
| Marca e integridad documental | MixTick sigue siendo nombre de trabajo. Los checksums originales describen el paquete de traspaso y no los archivos modificados del proyecto |

- **Archivos de documentación actualizados:** `README.md`, `docs/PROGRESS.md`,
  `docs/10_DECISIONS.md`, `docs/adr/015_FOUNDATION.md`, este informe,
  `supabase/README.md`, `integration_test/README.md`, evidencias y renders.
  La documentación de requisitos y los prompts de siguientes fases se conservan.
- **Decisiones nuevas/ADR:** [ADR-015](../adr/015_FOUNDATION.md): versiones
  contrastadas con documentación oficial; estructura por funcionalidades;
  acceso informativo sin login ficticio; sesión vía repositorio; configuración
  pública por dart-define; localización `es_ES` con fallback; barra de cuatro
  destinos y abreviaciones inferiores con títulos/tooltips completos.
- **Pendientes para la siguiente fase:** tras autorización de Fase 02,
  implementar migraciones, catálogo/alias y seed controlado, RLS en tablas y
  relaciones, permisos Storage y tests multiusuario. No se ha iniciado esa
  implementación. Más adelante, Fase 03 implementará Auth/perfil reales;
  distribución y pruebas iOS requieren su entorno correspondiente.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene el trabajo para revisión
  del propietario. No se han hecho commits, push, despliegues, compras ni
  cambios remotos de backend.

# Informe final FASE 05 — Comunidad y recetas guardadas

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente `prompts/05_COMMUNITY.md` y la
  autorización adjunta del propietario, conservar Fases 01–04, ocho migraciones,
  cuatro pestañas e identificadores, e integrar Comunidad con Mi recetario real.
- **Resultado:** **VERIFIED LOCAL** para los flujos enumerados de Flutter,
  Supabase local/Auth/PostgREST/Storage/RLS y Android. **NOT_RUN:** iOS y móvil
  físico. **NOT_VERIFIED:** backend/correo remoto, CDN, Realtime social o
  colaborativo, worker, eliminación completa de cuenta y moderación operativa.
  No se declara lista para publicación. Sin commit/push/deploy ni Fase 06.

- **Funcionalidades implementadas:** feed público cronológico con fotografía,
  autor/avatar, categoría, tiempo, recuentos y flags sociales; búsqueda de
  título/categoría/ingrediente y filtros, debounce/cancelación, paginación
  progresiva, refresh, deduplicación y reintento. Likes, guardados por referencia,
  comentarios paginados/borrado propio, seguimiento y perfiles con recetas
  públicas. Denuncia receta/comentario/perfil y bloqueo/desbloqueo. Guardadas
  reales dentro de Mi recetario con búsqueda/paginación/detalle original.
  Detalle reutilizado con permisos de autor y controles sociales. Material 3,
  claro/oscuro, español localizable, plurales, estados accesibles y texto al 200 %.
  Onboarding de perfil para participar; sin contenido ficticio en la app/seed.

- **Cambios de código:** lista de rutas reales principales; el
  [inventario completo](phase05/evidence/changed-files.txt) se compara con el
  workspace **aprobado de Fase 04**, que todavía no tenía commit, no con HEAD.

| Área | Archivos creados/modificados |
|---|---|
| Comunidad tipada | `lib/features/community/domain/community.dart`, `community_repository.dart`: receta/perfil reutilizados, consulta, cursor, comentarios, errores/cancelación |
| Backend real | `data/supabase_community_repository.dart`: proyecciones/RPC e INSERT/DELETE existentes, identidad antes/después de await, errores tipados |
| Estado | `presentation/community_providers.dart`, `lib/core/network/content_revision.dart`: páginas por consulta/cuenta, generaciones, cancelación y reconciliación de pantallas |
| UI Comunidad | `community_page.dart`, `community_browse.dart`, `community_widgets.dart`, `community_detail_social.dart`, `comments_page.dart`, `blocked_authors_page.dart` |
| Integración | `lib/features/recipes/presentation/recipes_page.dart`, `recipe_detail_page.dart`, `recipe_providers.dart`: guardadas reales, detalle único y revisión tras CRUD/privacidad |
| Perfil/navegación | `lib/features/profile/presentation/public_profile_page.dart`, `profile_providers.dart`, `lib/app/router.dart`, `lib/core/widgets/access_revalidation.dart`: perfil social, rutas auxiliares, revalidación y desalojo de avatar |
| Localización | `lib/app/localization/app_es.arb` y Dart generado: español y plurales; recursos regionales/pins conservados |
| SQL | `supabase/migrations/20261013000900_community_projection.sql`, `supabase/tests/004_community.test.sql` |
| Tests Flutter | `test/community/community_test.dart`, `community_transport_test.dart`, `test/support/fake_community_repository.dart`; adaptación de un caso obsoleto en `test/recipes/recipe_test.dart` |
| Cliente real | `test_support/community_local.dart`: A/B/C reales y dos casos híbridos identificados |
| Android | `integration_test/community_native_test.dart`, `scripts/verify_native_community.ps1`, `capture_community_android.py` |
| Reproducción/auditoría | `verify_community.ps1`, `cleanup_community_fixtures.py`, `audit_local_community_database.sql`; parámetro de evidencias en `verify_native_recipes.ps1`/`drive_recipe_gallery.py` |
| Documentos | README raíz/backend/integración, PROGRESS, decisiones, Storage, `docs/18_COMMUNITY.md`, ADR-019, este informe y evidencias |

La [auditoría de integridad](phase05/evidence/accepted-phases-integrity.json)
compara hashes capturados **antes de editar**. Permanecen intactos los ocho SQL,
informes/evidencias 01–04, tests anteriores salvo el caso explicado, Auth,
modelos/repositorios de perfil, cocina/compra, barra/tema, Android/iOS,
producto/config Supabase y versiones. Flutter **3.47.7**, Dart **3.13.5**;
ninguna dependencia nueva. El código original de la integración Android de
recetas se conserva. Los helpers admiten otro destino para no sobrescribir
capturas/evidencias históricas y limpian logs al inicio para evitar datos antiguos.

- **Migraciones/backend:** exclusivamente `mixtick-phase02` local, PostgreSQL
  **17.11**. 009 es aditiva; 001–008 no se editan. Mantiene **16 tablas públicas**,
  ahora **5 privadas**, **50 ingredientes / 74 alias**.

| Contrato nuevo | Motivo y permisos |
|---|---|
| `community_page` | Feed/búsqueda/guardados/autor y recuentos en una petición, cursor publicación/UUID, límite 1–50. **Invoker**, RLS en todas las relaciones; privadas excluidas también para su propietario |
| `community_categories`, `community_author` | Categorías/perfil mínimo/recuentos autorizados, **invoker**, sin conteos privilegiados ni email |
| Índice público descendente | Orden estable por publicación inicial e ID; republicar conserva published_at histórico |
| `create_comment_once` + ledger privado | Solicitud por actor/request, ID del comentario generado por servidor, hash y tombstone; retry no duplica ni sondea comentarios ajenos. Wrapper invoker/private definer cerrado, Auth como actor |
| CHECK de comentario | Rechaza whitespace sin contenido, también en INSERT directo; conserva tamaño y quota histórica |

Se conservan RLS/grants/PK de interacciones, submit_report y las cuotas. No se
añade una vista definer, Storage público, contador editable, panel administrativo
o Realtime social. [Contrato completo y cobertura de búsqueda](../18_COMMUNITY.md),
[ADR-019](../adr/019_COMMUNITY.md). Reset real desde cero aplica las nueve; SQL,
API y clientes anteriores pasan. No hubo link, db push, deploy ni backend remoto.

- **Comandos ejecutados:** `<FLUTTER>/<DART>` están en
  `C:\Users\Sergio\develop\flutter\bin`; `<PY>` es Python funcional 3.12.14
  del runtime; `<CLI>` la CLI portátil 2.120.0. `<NET>` es el ID completo de
  `mixtick-local-tests`, usado con adaptador loopback. Argumentos/horas/códigos
  reales: [calidad final](phase05/evidence/results.json),
  [backend/Android/APK](phase05/evidence/results-backend-and-native.json),
  [última suite de guardados](phase05/evidence/results-community-pagination.json),
  [reset e intento inicial](phase05/evidence/results-native-ui-initial.json) y
  [auditoría](phase05/evidence/results-audit.json). El JSON combinado contiene
  una ejecución anterior con 82 Flutter y 29 Comunidad; las salidas/JSON finales
  indicadas verifican **83** y **30** tras añadir sus casos específicos.

| Comando/comprobación final | Código | Resultado verificable |
|---|---:|---|
| `start_isolated_supabase.ps1` / `assert_local_isolation.ps1` | 0 | PASS: bindings/listeners 127.0.0.1, 18 probes de otras interfaces sin conexión. [JSON](phase05/evidence/isolation.json) |
| `<CLI> db reset --local --network-id <NET>` mediante adaptador | 0 | PASS: 001–009 desde cero. [Salida](phase05/evidence/db-reset.txt) |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 50 checks, 4 archivos; 35 anteriores +15. [Salida](phase05/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: results vacío. [Salida](phase05/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI> --evidence-dir .../regression-db` | 0 | PASS: 20 escenarios reales anteriores A/B/C. [Salida](phase05/evidence/api-regression.txt) |
| `<FLUTTER> test test_support/recipes_local.dart --dart-define-from-file=.tooling/phase05-client.local.json --reporter expanded` | 0 | PASS: 16, incluido 1 híbrido histórico. [Salida](phase05/evidence/recipes-real-client.txt) |
| `<FLUTTER> test test_support/community_local.dart --dart-define-from-file=.tooling/phase05-client.local.json --reporter expanded` | 0 | PASS: 30, 28 sin adaptación de transporte y 2 híbridos. [Salida](phase05/evidence/community-real-client.txt) |
| `cleanup_recipe_fixtures.py` / `cleanup_community_fixtures.py` | 0 | PASS: solo identidades/objetos registrados en esta ejecución, cola/referencia comprobadas. [Recetas](phase05/evidence/client-fixture-cleanup.txt), [Comunidad](phase05/evidence/community-fixture-cleanup.txt) |
| Suite Auth anterior con auto-confirmación local | 0 | PASS: 13. [Salida](phase05/evidence/auth-regression-auto-confirm.txt) |
| Suite Auth anterior con confirmación Mailpit activada temporalmente | 0 | PASS: 13; config original restaurada. [Salida](phase05/evidence/auth-regression-email-confirm.txt) |
| `verify_native_recipes.ps1 -EvidenceDirectory docs/reports/phase05/recipe-regression/evidence` | 0 | PASS: 1 test Android de CRUD/privacidad/galería real. [JSON](phase05/recipe-regression/evidence/native-results.json), [salida](phase05/recipe-regression/evidence/native-recipes.txt) |
| `verify_native_community.ps1` / `flutter test integration_test/community_native_test.dart -d emulator-5554 --no-uninstall ...` | 0 | PASS: 1 test Android con flujos múltiples reales. [JSON](phase05/evidence/native-results.json), [salida](phase05/evidence/native-community.txt) |
| `<FLUTTER> gen-l10n` | 0 | PASS. [Salida](phase05/evidence/gen-l10n.txt) |
| `<FLUTTER> analyze` | 0 | PASS: sin incidencias. [Salida](phase05/evidence/flutter-analyze.txt) |
| `<FLUTTER> test --reporter expanded` | 0 | PASS: 83. [Salida](phase05/evidence/flutter-test.txt) |
| `<DART> format --output=none --set-exit-if-changed lib test test_support integration_test scripts/loopback_docker.dart` | 0 | PASS: 87 archivos, 0 cambios. [Salida](phase05/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: mixtick, applicationId/namespace/MainActivity y 3 Runner iOS correctos. [Salida](phase05/evidence/identifiers.txt) |
| `<FLUTTER> build apk --debug` | 0 | PASS: APK estándar de lib/main.dart. [Salida](phase05/evidence/android-debug-build.txt) |
| SQL de auditoría, Mailpit y parada local | 0 | PASS: fixtures cero, catálogo conservado y stack apagado. [BD](phase05/evidence/database-audit.json), [correo](phase05/evidence/mail-audit.json), [parada](phase05/evidence/local-stop-verification.txt) |
| Identificación/parada del emulador propio | 0 | PASS: Pixel_10a, Android 17/API 37; modo noche restaurado y emulador cerrado. [Metadata](phase05/evidence/android-emulator.json), [parada](phase05/evidence/emulator-stop.txt) |
| iOS build/device y Android físico | — | NOT_RUN: Windows sin Xcode / sin móvil físico disponible |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **245.773.156 bytes**,
SHA256 **0D282F5CF1758DFCBA86D8EF4190B0D39E3886C235ADB91F450505506C74F1EB**.
[Hash](phase05/evidence/apk-sha256.json),
[identidad](phase05/evidence/apk-identity.txt): es.sergiotech.mixtick/MixTick,
compileSdk 36. Debug, sin firma/distribución; configuración pública externa
por dart-define. El APK estándar y el APK de integración son distintos.

- **Pruebas:** 83 Flutter =66 anteriores (un caso adaptado) +15 nuevas de
  validación/widgets/estado +2 de sockets; 50 SQL; 20 API; recetas 16; Comunidad
  30; Auth 13 por modo y 2 pruebas Android. La siguiente matriz usa C01–C32
  de la autorización, sin renumerar la matriz histórica del paquete.

| Caso | Estado | Evidencia y alcance |
|---|---|---|
| C01 publicar/feed | PASS | Cliente real A publica; B/C consultan cabecera/autor/foto; Android muestra el feed |
| C02 privadas excluidas | PASS | Ni A ni B/C las obtienen en feed/categoría/búsqueda; Android no muestra privada de A |
| C03 título | PASS | SQL/API real, tildes y `%_` literal; debounce obsoleto en mock; cancelación de socket real con actor/servidor de transporte de test |
| C04 categoría | PASS | Filtro real exacto y categorías privadas ausentes |
| C05 ingrediente | PASS | Alias canónico completo y texto libre normalizado exacto; fragmentos/ambigüedad no se afirman como equivalencias |
| C06 paginar/deduplicar | PASS | Feed real 8+1; cursor de publicación; mock con solapamiento y respuesta obsoleta descartada |
| C07 detalle correcto | PASS | UUID/autor/ingredientes/pasos originales; widget y Android navegan al detalle existente |
| C08 like/unlike | PASS | Recuento real 1→0, flags y UI Android; fallo de escritura se reconcilia en mock |
| C09 duplicados | PASS | Likes concurrentes/repetidos reales; borrado por C no afecta B; doble envío bloqueado en mock |
| C10 comentar | PASS | Texto/autor/fecha reales, petición concurrente idempotente, páginas de comentarios y creación Android |
| C11 inválido | PASS | Cliente y INSERT/RPC rechazan vacío, whitespace y exceso; payload diferente con request previo da conflicto |
| C12 borrar propio | PASS | Borrado real, contador 0 y tombstone sin resurrección; UI Android confirma |
| C13 borrar ajeno | PASS | Repositorio deniega y DELETE API devuelve cero filas; comentario conservado |
| C14 seguir/dejar | PASS | Backend real repetido/concurrente, flags/recuentos y recetas públicas de autor; seguir en Android |
| C15 autoseguimiento | PASS | Cliente y API directa rechazan |
| C16 guardar | PASS | Referencia real a UUID/autor de A; ninguna receta copiada a B |
| C17 Mi recetario | PASS | Consulta real de 9 guardadas con búsqueda/categoría y páginas 8+1; UI Android y widget muestran Guardadas |
| C18 retirar | PASS | DELETE repetido, lista vacía y receta original conservada; widget sincroniza detalle/recetario |
| C19 duplicados guardado | PASS | Inserción concurrente/repetida queda en una referencia; C no consulta los guardados de B |
| C20 privatizar guardada | PASS | B/C pierden agregado, relaciones, comentarios, búsquedas/recuentos y descarga/firma nueva en regresiones; Android pierde detalle; mock oculta agregado cacheado por permiso fresco |
| C21 interacciones privadas | PASS | Likes/saves/comments privados ajenos y suplantación de identidad denegados mediante API directa |
| C22 bloquear/desbloquear | PASS | Backend repetido y UI Android reales; se elimina solo el bloqueo propio |
| C23 restricciones | PASS | Feed/perfil/receta/avatar/follow ocultos o denegados en ambas direcciones; C no bloqueado mantiene acceso |
| C24 denuncia | PASS | Receta/comentario/perfil reales, informe propio/open; envío y confirmación de perfil Android |
| C25 denuncia inválida | PASS | Privada ajena, inexistente, bloqueado, motivo corto y edición de status denegados |
| C26 no filtraciones | PASS | Joins/contadores/ingredientes/guardados no amplían permisos; interacciones de C bloqueado se excluyen; anon sin RPC nuevos |
| C27 coherencia | PASS | Mock feed→guardadas→detalle→retirar y Android B guarda/abre el original desde Mi recetario |
| C28 red | PASS | Mock error/reintento y caso híbrido de transporte seguido de respuesta real; sockets cancelados identificados |
| C29 cuentas | PASS | Mock descarta página/diálogo/borrador; híbrido retrasa lectura real B→C y no escribe como C; logout/login Android B→A sin borrador/guardados ajenos |
| C30 Mi recetario | PASS | 16 casos reales anteriores, CRUD adicional y su integración Android original conservada |
| C31 cuatro pestañas | PASS | Foundation anterior y nuevas tarjetas/guardadas a 320×640/200 % claro/oscuro; Android mantiene 4 destinos |
| C32 Android real | PASS | 1 prueba con backend local real y flujos múltiples; sin repositorios simulados |

Los mocks solo prueban UI/estado. Los dos tests de socket tienen actor fijo y
servidor HTTP de transporte: no prueban RLS/Auth. Dos de los 30 casos cliente
son híbridos: una caída de transporte y una respuesta **real** retenida durante
un cambio **real** B→C; el resto no usa fallos de transporte simulados. Los
clientes de permisos usan clave pública y JWT de A/B/C reales, nunca service_role.
La quota real de comentarios continúa rechazando el siguiente intento aunque
se borre un comentario. Las limitaciones históricas de las suites Auth/recetas
se conservan, no se convierten en nuevas pruebas RLS.

- **Seguridad:** servidor como autoridad; privadas ausentes de Comunidad, saved
  sin permisos adicionales, RLS aplicada también a agregados/recuentos y bloqueos.
  Identidad de escrituras derivada de Auth; ledger de comentarios aislado por
  actor. Fotos privadas con referencia actual, descarga autenticada y desalojo de
  memoria; sin URLs firmadas emitidas por la app ni caché persistente nueva.
  Guards/SessionScope/generaciones impiden conservar datos visibles de otra
  cuenta; permiso fresco puede ocultar un agregado previamente cargado.

La limpieza administrativa **solo de fixtures** se ejecuta en host local,
validando UUID/email p4/p5 example.test y rutas/owners. Usa Storage API antes de
retirar exclusivamente esas cuentas; no es código Flutter, prueba de permisos
ni worker de producción. [Auditoría de patrones de secretos](phase05/evidence/secret-audit.json).
Auditoría final: cero usuarios, perfiles, recetas, relaciones sociales, listas,
fotos/avatares, jobs, ledgers, ventanas de quota y correos. Se mantienen esquema
y catálogo. Solo se apagan mixtick-phase02 y el emulador que creó esta fase;
no se modifica Docker global, firewall, otros proyectos o datos de app ajenos.

- **Capturas:** reales del emulador Pixel_10a, Android 17/API 37; inspeccionadas
  visualmente. La imagen/avatares son fixtures controladas codificadas y subidas
  mediante Auth/Storage reales, no fotografías de producción ni recetas demo
  suministradas por la aplicación. [Registro de captura](phase05/evidence/native-captures.txt).

| Pantalla | Evidencia |
|---|---|
| Comunidad clara | [Captura](phase05/previews/community-light.png) |
| Comunidad oscura | [Captura](phase05/previews/community-dark.png) |
| Guardadas, pestaña seleccionada y cabecera | [Captura](phase05/previews/saved-header.png) |
| Guardadas, tarjeta y acciones | [Captura](phase05/previews/saved-recipes.png) |
| Regresión galería/editor/detalle anterior | [Capturas separadas](phase05/recipe-regression/previews/) |

- **Problemas encontrados y correcciones:** los FAIL iniciales se conservan.

| Problema | Corrección/evidencia |
|---|---|
| Avisos/errores de primera implementación | Braces, API TickerMode actual, WidgetRef/context.mounted y clave localizada correcta; analyze final limpio. [Inicial](phase05/evidence/analyze-initial.txt) |
| Test R12 esperaba «guardadas próximamente» | Solo se adapta ese caso a la funcionalidad autorizada: conserva búsqueda/4 tabs/no datos ficticios y comprueba la sección real sin backend. No se conserva una afirmación que ya no es cierta. [Fallo inicial](phase05/evidence/flutter-regression-initial.txt) |
| Sintaxis/import en harness nuevo | Corregidos; [salida inicial](phase05/evidence/flutter-test-next.txt) y [análisis](phase05/evidence/analyze-tests-initial.txt) |
| Widgets lazy/posiciones antes del siguiente frame | Harness desplaza y espera controles reales; selector .first sobre ausencia corregido. [Inicial](phase05/evidence/community-widgets-initial.txt), [siguiente](phase05/evidence/community-widgets-next.txt) |
| Windows PowerShell trató progreso de adb push como error | Lanzador usa PowerShell 7; primer intento se interrumpe antes de iniciar Flutter y no se cuenta como integración. [FAIL](phase05/evidence/native-recipes-shell-initial.txt), [JSON](phase05/evidence/results-native-shell-initial.json) |
| Desplegable de denuncia y filtro de perfil indistinguibles en test | Finder limitado al AlertDialog. [FAIL real](phase05/evidence/native-community-initial.txt), [JSON](phase05/evidence/native-results-initial.json); ejecución final PASS |
| Gestión de respuestas tardías/borrado de comentarios | Request por actor/ledger/tombstone; comprobación de identidad antes de escribir tras await; cancelación SDK/socket y descarte de generaciones verificados |
| UI de guardados/plural | Captura adicional muestra pestaña seleccionada; «1 comentario» localizado y contraste claro/oscuro inspeccionado |
| Advertencias Gradle/JDK heredadas | Compilación/Android terminan; no se afirma entorno sin advertencias ni licencias adicionales aceptadas |

- **Limitaciones y riesgos:** la búsqueda por ingrediente no es semántica general:
  alias/canónico completo o texto libre normalizado exacto. No hay recomendador
  o algoritmo de «¿Qué cocino hoy?». Sin Realtime social, un cambio de otra sesión
  puede permanecer en el frame ya descargado hasta revalidación: apertura,
  regreso/activación/foreground/manual y cada 30 s visible. Durante consulta/error
  se oculta contenido previo. No se promete revocación instantánea de copias ni
  de URLs firmadas antiguas; los accesos nuevos siempre dependen del servidor.
  Cambios concurrentes en páginas requieren refresh. No hay modo offline completo
  ni benchmark de producción. La lista de bloqueos no elude perfiles ocultos:
  usa etiqueta/fragmento de ID, puede seguir oculto un bloqueo inverso.
  iOS/físico, remoto/CDN/Realtime, worker con gracia y referencia coordinada,
  eliminación de cuenta y moderación operativa siguen pendientes de lanzamiento.

- **Archivos de documentación actualizados:** README raíz/backend/integración,
  PROGRESS, decisiones, Storage, `docs/18_COMMUNITY.md`, ADR-019, este informe,
  inventario, JSON/salidas/capturas de Fase 05. Informes históricos intactos.
- **Decisiones nuevas/ADR:** [ADR-019](../adr/019_COMMUNITY.md).
- **Pendientes para la siguiente fase:** revisión del propietario. Únicamente
  tras autorización, Fase 06 sobre recetas/catálogo aprobados; no se ha iniciado.
  Los gates anteriores deben cerrarse antes de publicación y no se implementan
  automáticamente fuera de alcance.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene para revisión. HEAD continúa
  `cc9be3972d6fc0297d56174b3dfdce69d9719504`; Fases 04/05 quedan locales,
  sin commit/push, despliegues, proyectos remotos o publicación.

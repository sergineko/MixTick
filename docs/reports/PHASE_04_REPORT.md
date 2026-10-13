# Informe final FASE 04 — Mi recetario

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente `prompts/04_MY_RECIPES.md` y la
  autorización adjunta del propietario. Conservar Fases 01/02/03, siete
  migraciones históricas, cuatro módulos e identificadores, y entregar CRUD
  real/privado, catálogo, pasos, fotografías y cambios de visibilidad.
- **Resultado:** **VERIFIED LOCAL** para los flujos enumerados de Flutter,
  Auth/PostgREST/Storage/RLS y Android. Se completó la selección/cancelación
  real de galería. No equivale a distribución preparada. **NOT_RUN:** iOS y
  dispositivo físico. **NOT_VERIFIED:** backend/correo remoto, CDN, Realtime
  colaborativo, trabajador físico, eliminación completa de cuenta y moderación
  operativa. Se detiene para revisión; Fase 05 no autorizada.

- **Funcionalidades implementadas:** listado propio con fotografía/título/
  categoría/tiempo y distintivo privado/público; búsqueda por título, filtros y
  paginación por actualización/UUID. Crear/editar/detalle/eliminar, raciones,
  tiempos, descripción, ingredientes normalizados o texto libre validado,
  cantidad/unidad/opcional, pasos editables/reordenables. Publicar/privatizar
  mediante RPC explícita y confirmación. Foto real, preview, validación,
  reencodificación, subida/referencia, retirada/sustitución, errores/cancelación.
  Detalle reutilizable. Estados vacíos/carga/error/reintento, M3 claro/oscuro y
  español localizable. Guardadas es informativo hasta Fase 05, sin datos simulados.

- **Cambios de código:** rutas reales principales en la tabla; el
  [inventario completo](phase04/evidence/changed-files.txt) incluye documentación,
  scripts, pruebas, evidencias y capturas.

| Área | Archivos creados/modificados |
|---|---|
| Modelos/contratos | `lib/features/recipes/domain/recipe.dart`, `recipe_repository.dart`: DTO, validación, cantidades, catálogo, filtros/cursor y errores tipados |
| Datos reales | `lib/features/recipes/data/supabase_recipe_repository.dart`: consultas propias, RPC existentes/nuevas, Auth, Storage y comprobación de identidad tras await |
| Estado | `presentation/recipe_providers.dart`: paginación/generaciones, datos por usuario, acciones serializadas, foto/cancelación y reconciliación |
| UI | `recipes_page.dart`, `recipe_editor_page.dart`, `ingredient_editor.dart`, `recipe_detail_page.dart`, `recipe_widgets.dart`: formulario/lista/detalle/diálogo, confirmaciones y componentes reutilizables |
| Navegación/localización | `lib/app/router.dart`, `lib/app/localization/app_es.arb`, Dart generado: solo rutas de receta y textos españoles nuevos |
| iOS fuente | `ios/Runner/Info.plist`: descripción opcional de acceso a fotos ahora menciona recetas y perfil; identificadores intactos; compilación NOT_RUN |
| Backend | `supabase/migrations/20261013000800_recipe_editor_safety.sql`, `supabase/tests/003_recipe_editor.test.sql` |
| Unit/widget | `test/recipes/recipe_test.dart`, `test/support/fake_recipe_repository.dart` (mocks identificados) |
| Cliente real | `test_support/recipes_local.dart`: Auth/API/Storage A/B/C y un fallo híbrido declarado |
| Android | `integration_test/recipe_native_test.dart`, `test_support/generate_recipe_gallery.dart`, `scripts/verify_native_recipes.ps1`, `drive_recipe_gallery.py` |
| Herramientas | `scripts/verify_recipes.ps1`, `cleanup_recipe_fixtures.py`, `audit_local_recipe_database.sql` |
| Documentos | README raíz/backend/integración, PROGRESS, decisiones, Storage, `docs/17_MY_RECIPES.md`, ADR-018 y este informe |

Sin dependencias nuevas ni cambios de versiones: Flutter **3.47.7**, Dart
**3.13.5**, stack de Fase 03 conservado. Reutiliza picker/procesador verificados.
La [comparación de fases aceptadas](phase04/evidence/accepted-phases-diff.txt)
confirma sin cambios en los siete SQL históricos, informes/evidencias aceptados,
Auth/perfil, otros tres módulos, tema, tests anteriores, producto/config y pins.
Mi recetario y rutas/localización cambian dentro del alcance autorizado.

- **Migraciones/backend:** exclusivamente Docker local `mixtick-phase02`,
  PostgreSQL **17.11**; no link/db push/deploy remoto. 008 añade un ledger técnico
  privado de creación, wrappers invoker `create_recipe_once`,
  `lookup_recipe_creation`, `delete_recipe_versioned`, índice reciente y ciclo
  de fotografías. Conserva save_recipe/set_recipe_visibility/set_recipe_photo/
  resolve_ingredient y DELETE propio histórico. Ninguna tabla de producto nueva:
  **16 públicas / 4 privadas**, **50 ingredientes / 74 alias**.

La justificación es concreta: evitar duplicación cuando se pierde respuesta de
creación, controlar borrado frente a versión nueva, encolar fotos anteriores y
evitar leer staging/archivos sustituidos de una receta ya pública. Definers
cerrados, permisos mínimos y actor derivado de Auth. Reset desde cero aplica
001–008, y la regresión de contratos anteriores pasa. Detalles:
[Mi recetario](../17_MY_RECIPES.md) y [ADR-018](../adr/018_MY_RECIPES.md).

- **Comandos ejecutados:** ejecutables/rutas/argumentos/horas/códigos reales en
  [results.json](phase04/evidence/results.json) y
  [native-results.json](phase04/evidence/native-results.json). `<FLUTTER>/<DART>`
  están en `C:\Users\Sergio\develop\flutter\bin`; `<PY>` es Python 3.12.14 del
  runtime instalado; `<CLI>` es Supabase CLI 2.120.0 en `.tooling/supabase/`.
  `<NET>` es la red `mixtick-local-tests`, usada por el adaptador loopback.

| Comprobación/comando final | Código | Estado/evidencia |
|---|---:|---|
| `start_isolated_supabase.ps1` / `assert_local_isolation.ps1` | 0 | PASS: bindings/listeners 127.0.0.1 y 18 probes de otras interfaces sin conexión. [JSON](phase04/evidence/isolation.json) |
| `<CLI> db reset --local --network-id <NET>` mediante adaptador | 0 | PASS: 8 migraciones desde cero. [Salida](phase04/evidence/db-reset.txt) |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 35 checks, 3 archivos. [Salida](phase04/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: results vacío. [Salida](phase04/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI> --evidence-dir .../regression-db` | 0 | PASS: 20 casos aceptados A/B/C. [Salida](phase04/evidence/api-regression.txt), [JSON](phase04/evidence/regression-db/api-results.json) |
| `<FLUTTER> test test_support/recipes_local.dart --dart-define-from-file=.tooling/phase04-client.local.json --reporter expanded` | 0 | PASS: 16 escenarios, 15 sin fallo de transporte simulado y 1 híbrido. [Salida](phase04/evidence/recipes-real-client.txt) |
| `<PY> scripts/cleanup_recipe_fixtures.py` | 0 | PASS: invariantes de referencia/cola y retirada solo de sus 3 cuentas/2 objetos. [Salida](phase04/evidence/client-fixture-cleanup.txt) |
| Suite Auth anterior, auto-confirmación local | 0 | PASS: 13. [Salida](phase04/evidence/auth-regression-auto-confirm.txt) |
| Suite Auth anterior, confirmación real Mailpit activada temporalmente | 0 | PASS: 13; config restaurada. [Salida](phase04/evidence/auth-regression-email-confirm.txt) |
| `<FLUTTER> gen-l10n` | 0 | PASS. [Salida](phase04/evidence/gen-l10n.txt) |
| `<FLUTTER> analyze` | 0 | PASS: sin incidencias. [Salida](phase04/evidence/flutter-analyze.txt) |
| `<FLUTTER> test --reporter expanded` | 0 | PASS: 66. [Salida](phase04/evidence/flutter-test.txt) |
| `<DART> format --output=none --set-exit-if-changed lib test test_support integration_test scripts/loopback_docker.dart` | 0 | PASS: 71 archivos, 0 cambios. [Salida](phase04/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: mixtick/es.sergiotech.mixtick, MainActivity y 3 configuraciones Runner. [Salida](phase04/evidence/identifiers.txt) |
| `<FLUTTER> build apk --debug` | 0 | PASS: APK de `lib/main.dart`, configuración pública externa; no distribución. [Salida](phase04/evidence/android-debug-build.txt) |
| `verify_native_recipes.ps1` / `<FLUTTER> test integration_test/recipe_native_test.dart -d emulator-5554 --no-uninstall ...` | 0 | PASS: 1 prueba Android con flujos múltiples y assertions de backend real. [Salida](phase04/evidence/native-recipes.txt), [galería/capturas](phase04/evidence/native-gallery.txt) |
| Limpieza fixtures Android | 0 | PASS: 2 cuentas/1 objeto, job de foto borrada comprobado antes del teardown. [Salida](phase04/evidence/native-fixture-cleanup.txt) |
| SQL de auditoría final y parada exclusiva | 0 | PASS: cero fixtures/correos, esquemas/catálogo conservados y sin contenedores/puertos del stack. [BD](phase04/evidence/database-audit.json), [correo](phase04/evidence/mail-audit.json), [parada](phase04/evidence/local-stop-verification.txt) |
| iOS build/device, Android físico | — | NOT_RUN: Windows sin Xcode / no móvil físico disponible |

APK final: `build/app/outputs/flutter-apk/app-debug.apk`, **245.695.558 bytes**,
SHA256 **6E842F84862FA2D868271DA60597E0E8C5379F93C64C6BDF53A1BCFD55A60E35**.
[Hash del archivo](phase04/evidence/apk-sha256.json),
[identidad real](phase04/evidence/apk-identity.txt): MixTick,
`es.sergiotech.mixtick`, MainActivity aprobada, compileSdk 36. Es debug y se
excluye de Git. No es el APK de integración. iOS solo fuente/IDs, no probado.

- **Pruebas:** 66 Flutter = 48 anteriores + 18 nuevas; 35 SQL = 25 anteriores
  + 10 nuevas; 20 API de regresión; 16 escenarios cliente receta; Auth 13 por
  cada modo y 1 prueba Android real. La matriz usa R01–R20 de la autorización
  de Fase 04 (no renumera la matriz histórica de `docs/08_ACCEPTANCE_TESTS.md`).

| Caso solicitado | Estado | Alcance comprobado |
|---|---|---|
| R01 crear privada | PASS | RPC real y UI Android; backend ignora publicación implícita |
| R02 varios ingredientes/pasos | PASS | 3/3 persistidos, catálogo y texto libre real; formulario UI |
| R03 cantidades/unidades/raciones | PASS | 1,25 kg, 0,125 cucharada y 2,5 raciones reales; límites/precisión/coma unit y Android |
| R04 recuperar todos los datos | PASS | DTO sobre cabecera/joins reales, foto y campos visibles |
| R05 editar/persistir | PASS | Agregado real y edición UI Android |
| R06 orden de pasos | PASS | Array reordenado persiste ordinales y lectura; UI Android sube paso |
| R07 opcionales | PASS | Bool real, presentación y selector Android |
| R08 publicar | PASS | Acción confirmada/UI y RPC; B/C leen cabecera/componentes/foto |
| R09 privatizar | PASS | Misma sesión B/C pierde lectura directa de receta, relaciones, descarga y nueva firma |
| R10 denegar ajeno | PASS | RPC/UPDATE/insert componente/borrado/subida en ruta de A intentados directamente por B/C |
| R11 borrar relaciones | PASS | Borrado versionado real, cascadas, foto inaccesible, job; UI Android |
| R12 buscar/filtrar/paginar | PASS | 9 recetas propias en páginas 8+1 sin duplicados, exclusión de B, categoría/visibilidad y `%_` literal; widget filtros |
| R13 procesar/subir foto | PASS | JPEG real reencodificado; pipeline anterior de metadatos preservado; selector Android real |
| R14 archivos inválidos | PASS | Bytes inválidos/ >2 MiB y cancelación previa rechazados, referencia válida preservada |
| R15 sustituir/retirar | PASS | Staging público no visible a terceros, cambio/quitar y job; controller conserva datos/foto original ante fallo y cancela sin vincular |
| R16 error de red/borrador | PASS | Widget mock preserva formulario; híbrido pierde respuesta tras commit real y reintento no duplica; HTTP sockets anteriores conservados |
| R17 no incompletos | PASS | Fallo SQL revierte cabecera/versión/componentes; creación concurrente idempotente y tombstone no resucita borrada |
| R18 concurrencia | PASS | Dos ediciones reales: una gana/otra PT409; borrado obsoleto denegado; UI bloquea guardado hasta recarga confirmada |
| R19 sesión | PASS | Cliente real y Android A→B sin receta/foto privada anterior; widget descarta borrador y cierra diálogo |
| R20 cuatro módulos | PASS | Foundation anterior y Android; perfil transversal sin quinta pestaña |

Los mocks de widgets nunca se presentan como RLS. El caso R16 de cliente recibe
una respuesta **real** de create_recipe_once, la consume y provoca una excepción
de transporte antes de entregarla al repositorio: es un fallo controlado,
identificado como híbrido. La integridad/reconciliación se consulta al servidor.
Las pruebas de permisos no usan ese adaptador ni service_role. Las suites Auth
anteriores conservan sus dos casos de transporte con alcance identificado.

- **Seguridad:** RLS/PostgreSQL/Storage siguen siendo autoridad. Terceros no ven
  recetas privadas ni ingredientes/pasos/fotos, y no escriben recetas ajenas.
  Publicar/privatizar no depende de un campo de Flutter. Control de versión,
  transacción del agregado, bloqueo y ledger evitan sobreescritura silenciosa,
  parcialidad y duplicación por reintentos. Estado/caché de imagen/diálogos se
  descartan al cambiar usuario; cada descarga revalida acceso y referencia.
  No hay claves privilegiadas en Flutter ni URLs públicas permanentes/firmadas
  emitidas por la app. El TTL y copia ya descargada no se confunden con revocación.

La limpieza host es una excepción **de fixtures**, no una integración de producto:
tras borrar receta, RLS ya no permite al autor retirar el blob. El script valida
identidades Auth example.test registradas por esta ejecución y path/owner exactos,
obtiene en memoria la clave administrativa **local**, llama a Storage API y
limpia solo esas filas. No se usa para demostrar permisos ni se añade a Flutter.
Antes del teardown se comprobaron los jobs de los archivos sin referencia y la
ausencia de job para una referencia activa. Nunca se afirma que encolar eliminó
físicamente el archivo. El trabajador real sigue pendiente.

- **Capturas:** Android 17/API 37, emulador Pixel_10a; imagen de entrada controlada
  generada por encoder, no contenido de producción. Son capturas reales del
  sistema/aplicación y fueron inspeccionadas visualmente. Se espera a cargar la
  imagen y estabilizar animaciones. Renders anteriores no se sobrescribieron.

| Pantalla | Evidencia |
|---|---|
| Selector de galería del sistema | [Captura](phase04/previews/gallery-system.png), [jerarquía/confirmación](phase04/previews/gallery-confirm.xml) |
| Editor | [Captura Android](phase04/previews/editor-gallery.png) |
| Detalle claro | [Captura Android](phase04/previews/detail-light.png) |
| Detalle oscuro | [Captura Android](phase04/previews/detail-dark.png) |

- **Problemas encontrados y soluciones:** se conservan registros FAIL; no se
  sustituyen por resultados inventados ni se ocultan ejecuciones intermedias.

| Incidencia | Corrección/evidencia |
|---|---|
| Prompt supuesto 04_RECIPES.md no existe | Se localizó y ejecutó el real 04_MY_RECIPES.md antes de implementar |
| Import de ProfileFailure incorrecto / avisos estilo | Import de dominio real y corrección; analyze final limpio. [Inicial](phase04/evidence/analyze-initial.txt) |
| Harness de stream sin primer evento / footer lazy no construido / varios Scrollable | Pump inicial acotado y scroll observado al listado; casos finales pasan. [FAIL iniciales](phase04/evidence/flutter-test-initial.txt) |
| Binding de widgets interceptaba HTTP / PKCE de test sin storage | Suite cliente fuera del binding mock y storage PKCE en memoria identificado. [Inicial](phase04/evidence/recipes-client-initial.txt), [siguiente](phase04/evidence/recipes-client-next.txt) |
| Android 17 Photo Picker usa Compose sin IDs de thumbnail | Jerarquía observada y etiqueta accesible de la única imagen controlada. [FAIL](phase04/evidence/native-recipes-gallery-initial.txt) |
| Selector fallido quedó delante del próximo APK | Runner cierra selector y fuerza proceso limpio, conserva app data. Se interrumpió solo la CLI nativa propia detenida antes del body. [Intento](phase04/evidence/native-results-connection-initial.json) |
| Android 17 exige Done tras seleccionar | Acción observada implementada; cancelación/selección real final PASS. [FAIL](phase04/evidence/native-recipes-confirm-initial.txt) |
| Test asumía URL externa de GoRouter tras replace | UUID se obtiene de RecipeDetailPage real, no del path anterior. [FAIL](phase04/evidence/native-recipes-route-id-initial.txt) |
| Primeras capturas durante carga/tween de tema | Se conserva evidencia transitoria; capturas finales esperan imagen/animación y muestran contraste correcto |
| Concurrencia y modal de ingrediente en cambio de cuenta | Guardado bloqueado hasta recarga real confirmada; diálogo ligado a actor/cierre y preview desalojado; widgets negativos pasan |
| Gradle/JDK | Avisos heredados de acceso nativo; builds/tests finalizan. No se afirma entorno sin advertencias |

- **Limitaciones y riesgos:** iOS/físico no probado. Cancelar no revierte una
  petición ya aceptada; texto/foto son operaciones separadas y se informa de foto
  pendiente. Nuevos accesos se deniegan al privatizar, pero copias/URLs existentes
  conservan sus límites. Worker de fotos debe usar gracia/referencia coordinada.
  Paginación puede necesitar refresh ante reordenación concurrente. No hay modo
  offline completo, Comunidad/guardadas real, matching, compra colaborativa,
  eliminación completa de cuenta, moderación operativa, backend remoto, CDN o
  cliente Realtime habilitados/verificados por esta fase.
- **Archivos de documentación actualizados:** README raíz, supabase/integración,
  PROGRESS, decisiones, Storage, `docs/17_MY_RECIPES.md`, ADR-018, informe y
  evidencias propias. Informes históricos conservados.
- **Decisiones nuevas/ADR:** [ADR-018](../adr/018_MY_RECIPES.md).
- **Pendientes para la siguiente fase:** revisar este resultado; solo con
  autorización explícita, Fase 05 Comunidad y guardadas, reutilizando el detalle.
  Los gates de lanzamiento se conservan y no se implementan automáticamente.
- **¿Autorizada siguiente fase?:** **NO**. Sin commit/push, despliegue remoto ni
  tiendas. HEAD continúa `cc9be3972d6fc0297d56174b3dfdce69d9719504`; Fase 04
  queda en el workspace para revisión.

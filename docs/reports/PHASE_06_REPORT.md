# Informe final FASE 06 — ¿Qué cocino hoy?

Fecha: 2026-10-13, Europe/Madrid. Plantilla: `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente `prompts/06_COOK_TODAY.md` y la
  autorización adjunta del propietario. Conservar Fases 01–05, nueve migraciones,
  cuatro pestañas e identificadores y convertir la selección temporal en
  resultados reales de recetas compatibles, sin despensa ni compra funcional.
- **Resultado:** **VERIFIED LOCAL** para las comprobaciones enumeradas de
  Flutter, PostgreSQL/Auth/PostgREST/Storage local y Android. **NOT_RUN:** iOS y
  móvil físico. **NOT_VERIFIED:** remoto/CDN/Realtime, worker de fotografías,
  eliminación completa de cuenta y moderación operativa. No equivale a publicación.
  Se detiene para revisión; sin commits/push, deploy o Fase 07.

- **Funcionalidades implementadas:** autocompletado del catálogo/nombres/alias,
  resolución autoritativa, nombres libres exactos, chips, contador, quitar uno,
  limpiar, prevenir duplicados y añadir sin cerrar el selector. Modos «Puedo
  cocinarlo» y «Me falta poco», páginas reales 8+1, ranking determinista,
  fotografías autenticadas, autor/categoría/tiempo/recuentos/estado/faltantes,
  detalle original y permisos habituales. Estados inicial/vacío/carga/error/
  reintento, refresh, descarte/cancelación y revisión de permisos. Material 3,
  claro/oscuro, español localizable y 320×640 al 200 %. Aviso de cantidades de
  casa no comprobadas. Contrato tipado de faltantes para Fase 07, sin escribir
  listas ni mostrar un botón de compra desconectado.

- **Cambios de código:** rutas reales principales. El
  [inventario completo](phase06/evidence/changed-files.txt) compara con el
  baseline de **562 archivos**, capturado antes de editar en HEAD aprobado
  `107d4fe3fda7b31d3dc826533833669d6f190765` después del push solicitado.

| Área | Archivos creados/modificados |
|---|---|
| Dominio tipado | `lib/features/cook_today/domain/matching.dart`: selección/consulta, match/cursor/página, cancelación/errores y transferencia de líneas faltantes |
| Repositorio real | `lib/features/cook_today/data/supabase_matching_repository.dart`: RPC acotada, actor antes/después de await, SDK abortSignal y errores tipados |
| Estado | `presentation/matching_providers.dart`: familias por consulta/cuenta, autoDispose, revisión compartida, generaciones y páginas sin duplicados |
| Interfaz | `presentation/cook_today_page.dart`: sustituye el placeholder, conserva teclado/texto nuevo durante resolución, reutiliza catálogo, RecipePhoto y detalle |
| Localización | `lib/app/localization/app_es.arb` y Dart generado; plurales/validadores/estados españoles |
| Backend | `supabase/migrations/20261013001000_cook_today_matching.sql`, `supabase/tests/005_matching.test.sql` |
| Unit/widget | `test/cook_today/matching_test.dart`: 4 unitarias y 12 de widgets/estado, mocks identificados |
| Cliente real | `test_support/matching_local.dart`: 23 escenarios A/B/C, dos híbridos de transporte |
| Android | `integration_test/matching_native_test.dart`, `scripts/verify_native_matching.ps1`, `capture_matching_android.py` |
| Reproducción/auditoría | `verify_matching.ps1`, `cleanup_matching_fixtures.py`, `audit_local_matching_database.sql`, `benchmark_matching.sql` |
| Documentación | README raíz/backend/integración, PROGRESS, decisiones, algoritmo, `docs/19_COOK_TODAY.md`, ADR-020, informe y evidencias |

Sin cambios en dependencias, versiones, identificadores, navegación/tema, Auth,
repositorios/modelos/detalle de recetas, Comunidad, perfil o compra. Los tests,
scripts e informes/evidencias históricos permanecen intactos; la regresión
Android de Mi recetario usa su código original y otra carpeta de salida.
[Auditoría de integridad](phase06/evidence/accepted-phases-integrity.json).
Flutter **3.47.7**, Dart **3.13.5**; ninguna dependencia nueva.

- **Migraciones/backend:** exclusivamente `mixtick-phase02` local, PostgreSQL
  **17.11**. 010 conserva 001–009. Siguen **16 tablas públicas / 5 privadas** y
  **50 ingredientes / 74 nombres/alias**. No hay nueva tabla de producto,
  despensa, política privilegiada, copia de receta, vista definer o cambio de Storage.

| Adición 010 | Justificación y contrato |
|---|---|
| `cook_today_page(uuid[],text[],text,jsonb,integer)` | Filtrar/contar/ordenar en servidor, sin descargar todas las recetas al móvil. SECURITY INVOKER, estable, search_path vacío, EXECUTE solo authenticated y RLS en todas las relaciones |
| Índice parcial `recipe_ingredients_free_match` | `(custom_key,recipe_id)` para igualdad de texto libre; conserva el índice de FK canónica existente |

La consulta valida Auth, máximo combinado 50 entradas, nombres 1–80, UUID
aprobados, modo exact/near, límite 1–50 y cursor completo/tipado. No SQL dinámico
ni comparación por subcadenas. Vacío retorna cero sin evaluar recetas. Reset
desde cero aplica las diez migraciones, SQL/lint y todas las regresiones pasan.
No link, db push, despliegue, backend remoto ni Git durante esta fase.

- **Algoritmo exacto:** claves canónicas por UUID; alias completos aprobados
  se resuelven mediante los contratos existentes. Un custom_name de receta
  que ahora tenga alias inequívoco usa esa equivalencia. Los demás nombres
  requieren custom_key normalizada exacta; no «miso» = «miso blanco», leche =
  nata, aceite = oliva/girasol, singularización genérica o sustituciones.
  Deduplicación por clave efectiva; una clave con línea obligatoria prevalece
  sobre su línea opcional. Las cantidades no participan en la comparación.

Sea R el conjunto obligatorio y S la selección: presentes `|R∩S|`, faltantes
`|R−S|`. Selección vacía y recetas sin obligatorios se excluyen de ambos modos.
Exact exige todos los obligatorios. Near exige al menos uno coincidente y
como máximo dos faltantes; incluye completas primero con etiqueta distinta.
Opcionales nunca excluyen ni aparecen como obligatorios faltantes.

Completas: mayor coincidencia opcional, menor tiempo, UUID ascendente.
Parciales: menos faltantes, más obligatorios coincidentes, menor tiempo, UUID.
Se reutiliza totalMinutes: suma de componentes indicados; desconocido cuando
faltan ambos, al final mediante sentinela interno 20161. Cursor ASC de
`(missing,rank,minutes,id)`, rank negativo de la coincidencia correspondiente.
Sin OFFSET/score/recomendador. Guardadas no son otra fuente: RLS de recipes
ya incluye propias privadas/públicas y ajenas públicas autorizadas, una vez.
Ediciones concurrentes requieren refresh; no se promete snapshot inmutable.

Contrato completo: [algoritmo](../06_MATCHING_ALGORITHM.md),
[módulo](../19_COOK_TODAY.md), [ADR-020](../adr/020_COOK_TODAY.md).
La elección invoker sigue la [documentación oficial de Supabase](https://supabase.com/docs/guides/database/functions).

- **Comandos ejecutados:** `<FLUTTER>/<DART>` en
  `C:\Users\Sergio\develop\flutter\bin`, `<PY>` Python funcional 3.12.14 del
  runtime y `<CLI>` Supabase CLI 2.120.0 portátil. `<NET>` es la red local
  `mixtick-local-tests` usada por el adaptador loopback. Argumentos/horas/códigos:
  [backend](phase06/evidence/results-backend.json),
  [calidad final](phase06/evidence/results.json),
  [calidad/APK](phase06/evidence/results-quality-and-apk.json),
  [ranking final](phase06/evidence/results-ranking.json),
  [benchmark](phase06/evidence/results-benchmark.json) y JSON nativos.

| Comprobación/comando final | Código | Resultado verificable |
|---|---:|---|
| `start_isolated_supabase.ps1` / `assert_local_isolation.ps1` | 0 | PASS: bindings/listeners loopback y 18 probes por otras interfaces sin conexión. [JSON](phase06/evidence/isolation.json) |
| `<CLI> db reset --local --network-id <NET>` mediante adaptador, con cero cuentas | 0 | PASS: diez migraciones desde cero. [Salida](phase06/evidence/db-reset.txt), [códigos](phase06/evidence/database-initial-results.json) |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 72 checks en cinco archivos, 50 anteriores +22. [Salida](phase06/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: results vacío. [Salida](phase06/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI> --evidence-dir .../regression-db` | 0 | PASS: 20 escenarios A/B/C reales anteriores. [Salida](phase06/evidence/api-regression.txt) |
| `<FLUTTER> test test_support/recipes_local.dart --dart-define-from-file=.tooling/phase06-client.local.json --reporter expanded` | 0 | PASS: 16 anteriores, uno híbrido histórico. [Salida](phase06/evidence/recipes-real-client.txt) |
| Igual con `test_support/community_local.dart` | 0 | PASS: 30 anteriores, dos híbridos históricos. [Salida](phase06/evidence/community-real-client.txt) |
| Igual con `test_support/matching_local.dart` | 0 | PASS: 23, 21 sin adaptación de transporte y dos híbridos. [Primera ejecución](phase06/evidence/matching-real-client.txt), [ranking final](phase06/evidence/matching-ranking-final.txt) |
| Suite Auth anterior con auto-confirmación local | 0 | PASS: 13. [Salida](phase06/evidence/auth-regression-auto-confirm.txt) |
| Suite Auth anterior con confirmación Mailpit activada temporalmente | 0 | PASS: 13, config restaurada. [Salida](phase06/evidence/auth-regression-email-confirm.txt) |
| `benchmark_matching.sql` por `docker exec ... psql -v ON_ERROR_STOP=1` | 0 | PASS: 6.000 recetas/18.000 ingredientes/6.000 pasos en rollback, páginas de 9 y cero restos. [Salida](phase06/evidence/matching-benchmark.txt) |
| `<FLUTTER> gen-l10n` | 0 | PASS. [Salida](phase06/evidence/gen-l10n.txt) |
| `<FLUTTER> analyze` | 0 | PASS: sin incidencias. [Salida](phase06/evidence/flutter-analyze.txt) |
| `<FLUTTER> test --reporter expanded` | 0 | PASS: 99. [Salida](phase06/evidence/flutter-test.txt) |
| `<DART> format --output=none --set-exit-if-changed lib test test_support integration_test scripts/loopback_docker.dart` | 0 | PASS: 93 archivos, cero cambios. [Salida](phase06/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: mixtick, es.sergiotech.mixtick y tres Runner iOS. [Salida](phase06/evidence/identifiers.txt) |
| `<FLUTTER> build apk --debug` | 0 | PASS: APK estándar de lib/main.dart. [Salida](phase06/evidence/android-debug-build.txt) |
| `verify_native_matching.ps1` / test `matching_native_test.dart -d emulator-5554 --no-uninstall ...` | 0 | PASS: una integración Android con flujos múltiples y backend real. [JSON](phase06/evidence/native-results.json), [salida](phase06/evidence/native-matching.txt) |
| `verify_native_recipes.ps1 -EvidenceDirectory docs/reports/phase06/recipe-regression/evidence` | 0 | PASS: integración anterior CRUD/galería real, conservada. [JSON](phase06/recipe-regression/evidence/native-results.json), [salida](phase06/recipe-regression/evidence/native-recipes.txt) |
| Teardown por manifiestos propios, auditorías y parada local | 0 | PASS: cero fixtures/objetos/correos y stack/emulador propio apagados. [BD](phase06/evidence/database-audit.json), [correo](phase06/evidence/mail-audit.json), [parada](phase06/evidence/local-stop-verification.txt), [emulador](phase06/evidence/emulator-stop.txt) |
| iOS build/device, Android físico | — | NOT_RUN: Windows sin Xcode / sin móvil físico disponible |

APK estándar: `build/app/outputs/flutter-apk/app-debug.apk`, **245.806.470 bytes**,
SHA256 **CC24600093D6124A45BCF5100CDFAC61AB7D2FB67EB5CE9C9A92D4C5D4238EED**.
[Hash](phase06/evidence/apk-sha256.json),
[identidad](phase06/evidence/apk-identity.txt): es.sergiotech.mixtick/MixTick,
MainActivity aprobada, compileSdk 36. Debug, excluido de Git, sin distribución.
No es el APK de integración. Configuración pública externa por dart-define;
no se incluye un backend real o recetas demo en el binario estándar.

- **Pruebas:** 99 Flutter =83 históricos intactos +16 nuevas; 72 SQL; 20 API;
  recetas 16; Comunidad 30; coincidencias 23; Auth 13 por modo y dos tests
  Android. Esta matriz usa M01–M34 de la autorización sin renumerar la matriz
  histórica del paquete. PASS significa el alcance indicado en cada fila.

| Caso solicitado | Estado | Evidencia y alcance |
|---|---|---|
| M01 catálogo | PASS | Mock selector y Android seleccionan ingredientes reales de catálogo |
| M02 alias | PASS | SQL/cliente real y Android Huevos/Patatas/AOVE → UUID canónico |
| M03 duplicados | PASS | Mock/Android muestran una etiqueta por UUID; SQL/cliente deduplican alias/ID |
| M04 eliminar | PASS | Widget mock elimina chip y cambia consulta a la selección restante |
| M05 limpiar | PASS | Widget mock elimina selección y no hace búsqueda vacía |
| M06 ambiguos/desconocidos | PASS | Widget literal; servidor no equipara aceite, subcadenas, leche/nata o texto de inyección |
| M07 completos | PASS | SQL/cliente real y Android con todos los obligatorios |
| M08 opcionales | PASS | SQL/cliente y Android sin cebolla opcional; cero faltantes |
| M09 excluir faltantes exact | PASS | Cliente real no devuelve recetas con uno/dos faltantes en exact |
| M10 falta uno | PASS | Cliente real y modo near Android; cantidad/unidad/ordinal/UUID original conservados |
| M11 faltan dos | PASS | Cliente real, dos obligatorios, ningún opcional obligatorio |
| M12 tres o más | PASS | Cliente real excluye receta con tres faltantes |
| M13 sin común | PASS | SQL/cliente excluyen parciales desconectadas |
| M14 orden | PASS | Cliente real: menos faltantes antes de tiempo, mayor obligatorio coincidente antes de una parcial más rápida, opcionales completos antes de tiempo; repeat estable |
| M15 fuentes/guardadas | PASS | Cliente/Android, guardado por referencia produce una tarjeta, ninguna copia |
| M16 texto libre | PASS | SQL resuelve alias legado almacenado como free; cliente exact normalizado distingue Miso blanco/rojo/fragmento |
| M17 vacío/sin obligatorios | PASS | SQL/cliente excluyen universalidad; widget vacío no consulta |
| M18 cantidades | PASS | Cliente receta de 1.000.000 kg coincide por presencia; DTO conserva cantidad requerida, no cantidad doméstica; aviso visible |
| M19 privada propia | PASS | Cliente A/B y Android A recuperan las suyas |
| M20 privada ajena | PASS | SQL/cliente/Android ocultan privada de A a B y privada confidencial C |
| M21 bloqueos | PASS | Cliente real simétrico, A/B ocultos, C autorizado y foto denegada a B |
| M22 privatización | PASS | Cliente nuevo query/SDK/foto y Android recarga detalle/regresa a resultados sin receta retirada |
| M23 relaciones/recuentos | PASS | RLS SQL/cliente: niños privados ocultos, matching sin IDs/títulos privados ni total global, saved no amplía acceso |
| M24 cuenta | PASS | Mock descarta selección/página tardía; híbrido retiene respuesta real B→C y repo la rechaza; Android logout/login limpia estado |
| M25 paginar | PASS | Cliente real 8+1 y varias páginas sin duplicados; mock solapamiento deduplicado |
| M26 obsoletas | PASS | Mock señal de cancelación/disposición y generación; escritura nueva durante resolución se conserva; SDK abortSignal implementado, transporte compartido mantiene sus tests reales históricos |
| M27 red | PASS | Mock error/reintento y caída híbrida de una solicitud, seguida de recuperación real |
| M28 detalle | PASS | Widget/Android verifican UUID original, pasos y ausencia de controles de autor ajeno |
| M29 cuatro pestañas | PASS | Foundation intacto, widgets y Android mantienen cuatro destinos |
| M30 Comunidad/recetario | PASS | 30/16 clientes históricos, 83 Flutter intactos y regresión Android original de recetas/galería |
| M31 Supabase real | PASS | A/B/C GoTrue/PostgREST/Storage locales, sin service_role para permisos |
| M32 Android | PASS | Una prueba real completa, ninguna sustitución de repositorio |
| M33 límites/consulta | PASS | Validaciones SQL/cliente negativas de null/límites/nombres/UUID/modo/cursor/anon y literal de inyección sin coincidencias |
| M34 móvil pequeño/texto | PASS | Dos widgets con selección/resultados al 200 % en 320×640 claro/oscuro; teclado rápido Android real |

Los cuatro tests unitarios y los doce widgets de selección/estado son mocks;
no prueban RLS. Los 22 nuevos checks SQL incluyen ocho estructurales y catorce
funcionales con fixtures/rol SQL en rollback; no se presentan como signup de
GoTrue. Los 23 escenarios del cliente usan usuarios reales A/B/C registrados
por Auth, clave pública y sus JWT. Dos son híbridos: caída controlada antes de
una RPC y respuesta real retenida durante un cambio real B→C. Los 21 restantes
no usan esa adaptación de transporte. Suites históricas mantienen sus alcances
híbridos/socket declarados. Setup Android usa cliente de fixtures local; la
app conserva Auth PKCE/almacenamiento seguro sin cambiar sus contratos.

- **Rendimiento:** benchmark SQL local con 6.000 recetas. Exact 1.911 s,
  near 3.138 s y página siguiente 3.637 s, nueve registros devueltos; cero pasos
  en respuesta de matching. Es una ejecución en Docker bajo rol autenticado,
  con datos temporales revertidos. No es un benchmark de producción, percentil
  de latencia o prueba de Auth real. No se promete búsqueda instantánea para
  cualquier volumen. El móvil recibe una página, no toda la base de recetas.

- **Seguridad:** invoker/RLS en cabecera, ingredientes, catálogo/alias y autor,
  privadas propias incluidas y ajenas ausentes. No se usa saved como permiso,
  ni contador privilegiado o ID protegido en cursor. Bloqueos históricos
  respetados. Fotografías y detalle reutilizan autorización actual; una
  privatización impide nuevas lecturas, mientras copias/URLs externas ya
  obtenidas conservan sus límites. No service_role/secret keys en Flutter.
  SessionScope/actor/generaciones descartan datos de otra cuenta, y fotografías
  se desalojan/revalidan. Página oculta deja de observar consultas de matching.

La limpieza administrativa **solo de fixtures** corre en host local y valida
manifiestos, UUID/email example.test/rutas/owners antes de retirar objetos y
cuentas. No es código Flutter, prueba de permisos ni worker. Final: diez
migraciones, 16+5 tablas, catálogo 50/74 y cero cuentas, perfiles, recetas,
componentes, relaciones, listas, fotos/avatares, jobs, ledgers, quotas y correos.
Se apagan solo mixtick-phase02 y el emulador creado/verificado por esta fase;
Docker global, firewall, otros proyectos y datos ajenos no se modifican.
[Auditoría de patrones de secretos](phase06/evidence/secret-audit.json).

- **Capturas Android:** Pixel_10a, Android 17/API 37; pantalla real, revisada
  visualmente. La figura de tortilla es una fixture codificada/subida mediante
  Auth/Storage, no foto de producción ni dato demo de la aplicación.
  La etiqueta roja visible documenta la prevención de una selección duplicada.

| Pantalla | Evidencia |
|---|---|
| Selección, contador y ambos modos | [Captura](phase06/previews/matching-selection.png) |
| Resultado completo claro | [Captura](phase06/previews/matching-light.png) |
| Resultado completo oscuro | [Captura](phase06/previews/matching-dark.png) |
| Diagnóstico inicial del selector/teclado | [Captura](phase06/previews/matching-debug-initial.png) |
| Regresión galería/editor/detalle | [Capturas separadas](phase06/recipe-regression/previews/) |

`native-failure-initial.png` muestra el launcher después de finalizar el intento
fallido; se conserva como diagnóstico, **no** se atribuye a matching. Capturas
anteriores de Fases 01–05 intactas. Modo noche restaurado, galería propia retirada
y emulador apagado con ownership/AVD comprobados.

- **Problemas encontrados y soluciones:** todos los FAIL iniciales conservados.

| Incidencia | Estado/corrección y evidencia |
|---|---|
| Patch con delete/add del mismo archivo rechazado; otro contexto no coincidía | FAIL de edición sin cambios, corregido con Update y contexto real. [Registro](phase06/evidence/patch-initial.txt) |
| Primer analyze: 15 avisos/advertencia | FAIL inicial, braces y resultado refresh usado; análisis final limpio. [Salida](phase06/evidence/analyze-initial.txt) |
| Catálogo sin backend activaba retry de Riverpod | Cuatro Foundation FAIL por timer pendiente. No se alteran tests: no observar catálogo cuando falta configuración. [Regresión inicial](phase06/evidence/flutter-regression-initial.txt) |
| Harness nuevo sin import y addAll esperaba Map | FAIL de compilación; import real y addEntries; compilador compartido también registró fallo de carga Foundation. [Analyze](phase06/evidence/analyze-next.txt), [tests](phase06/evidence/flutter-test-initial.txt) |
| Dos avisos de estilo en test nativo | FAIL analyze previo, braces explícitos; calidad final PASS. [Salida](phase06/evidence/analyze-pre-native.txt) |
| Selector Android borraba la tercera entrada rápida AOVE | Dos intentos FAIL conservados. Catálogo real 50, sin error, pero campo quedó vacío al deshabilitar/reabrir IME. Campo permanece activo, solo envío bloqueado; se limpia únicamente el texto original y se conserva la nueva entrada. Test nuevo de resolución retrasada y Android final PASS. [Inicial](phase06/evidence/native-matching-initial.txt), [diagnóstico](phase06/evidence/native-matching-diagnostic.txt), [JSON](phase06/evidence/native-results-initial.json) |
| Preflight Docker/ADB dentro del sandbox sin acceso | NOT_RUN inicial de ese preflight; repetido con permisos adecuados y PASS. No fue rechazo de aprobación ni prueba de aplicación |
| Gradle/JDK heredados | Avisos de acceso nativo; APK/tests terminaron con 0. No se afirma entorno sin advertencias |

- **Limitaciones y riesgos:** selección solo en memoria mientras vive la pantalla;
  ningún inventario o modo offline completo. Texto libre necesita nombre completo
  normalizado/alias registrado, sin equivalencias semánticas. Cambios concurrentes
  pueden reordenar páginas; refresh reconstruye. Sin Realtime, cambios de otra
  sesión pueden seguir en un frame descargado hasta apertura/retorno/activación/
  foreground/manual o revisión visible de 30 s; no se promete retirada retroactiva.
  SDK puede reintentar transporte y cancelar no revierte servidor. Coste de RLS
  y ranking requiere medir producción; benchmark local no garantiza latencias
  remotas. iOS/físico, remoto/CDN/Realtime, worker con gracia y revalidación,
  eliminación completa de cuenta y moderación operativa siguen pendientes.

- **Archivos de documentación actualizados:** README raíz/backend/integración,
  `docs/PROGRESS.md`, `docs/10_DECISIONS.md`, `docs/06_MATCHING_ALGORITHM.md`,
  `docs/19_COOK_TODAY.md`, ADR-020, informe e inventario/JSON/salidas/capturas.
  Informes y evidencias históricos conservados.
- **Decisiones nuevas/ADR:** [ADR-020](../adr/020_COOK_TODAY.md): comparación de
  presencia invoker, selección efímera, política sin obligatorios, ranking/cursor
  y DTO de faltantes sin anticipar compra.
- **Pendientes para la siguiente fase:** revisión del propietario. Solo tras
  autorización, Fase 07 integrará lista/confirmación/importación de faltantes
  revalidando acceso/versiones/ordinales y sin metadatos privados para miembros.
  Gates de lanzamiento anteriores se conservan.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene para revisión. HEAD sigue
  `107d4fe3fda7b31d3dc826533833669d6f190765`; cambios locales de Fase 06 sin
  stage/commit/push, despliegue, proyecto Supabase remoto o publicación.

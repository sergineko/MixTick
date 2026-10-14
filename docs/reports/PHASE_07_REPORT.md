# Informe final FASE 07 — Lista de compra compartida

Fecha: **2026-10-14, Europe/Madrid**. Sigue `templates/PHASE_REPORT.md`.

- **Objetivo:** ejecutar exclusivamente el prompt real
  `prompts/07_SHOPPING_REALTIME.md` y la autorización del propietario: completar
  Compra y conectar recetas/faltantes, manteniendo Fases 01–06, cuatro módulos,
  identificadores y las diez migraciones históricas.
- **Resultado:** **VERIFIED LOCAL** para las comprobaciones enumeradas:
  **114 Flutter**, **84 SQL**, **20 API**, recetas **16**, Comunidad **30**,
  matching **23**, compra **16**, Auth **13 por modo de correo**, **2 integraciones
  Android**, análisis/formato/IDs y APK. Realtime verificado mediante WebSockets
  independientes A/B y Android con backend real. **NOT_RUN:** iOS y móvil físico.
  **NOT_VERIFIED:** backend/correo remoto, CDN, worker físico, eliminación completa
  de cuenta, moderación operativa y rendimiento de producción. No declara el
  producto listo para distribución. Fase 08 no iniciada.

- **Funciones implementadas:** múltiples listas propias/compartidas, crear,
  título, renombrar y eliminar propias con confirmación; miembros e invitaciones
  por username registrado, aceptar/rechazar, revocar y abandonar. Productos
  libres/canónicos, nombre/cantidad/unidad, edición versionada, comprado/pendiente,
  borrado y grupos separados. Entrada rápida sin otra pantalla; cantidades con
  coma o punto, hasta tres decimales. Toggle optimista con lectura de servidor;
  conflictos no sobrescriben, borradores conservados ante errores de red.
  Realtime, reconexión, revalidación y cierre de canales por ruta/cuenta/permiso.
  Importar selección de receta o exclusivamente faltantes, revisión/destino/
  confirmación, cantidades originales y operación idempotente/atómica.
  Material 3, claro/oscuro, español localizable, pantalla pequeña y fuente al 200 %.

- **Cambios de código:** rutas principales reales en la tabla;
  [inventario completo](phase07/evidence/changed-files.txt) y
  [integridad de fases aceptadas](phase07/evidence/accepted-phases-integrity.json).

| Área | Archivos y comportamiento |
|---|---|
| Dominio | `lib/features/shopping/domain/shopping.dart`, `shopping_repository.dart`: DTO tipados, cantidades, invitaciones, snapshots, preview y señales |
| Datos | `data/supabase_shopping_repository.dart`: RPC/grants reales, actor antes/después de await, páginas de listas de 200 por UUID, snapshots y canales autorizados |
| Estado | `presentation/shopping_providers.dart`: Riverpod por lista/cuenta, generaciones, debounce, reconciliación, versión y descarte de datos denegados |
| UI | `shopping_page.dart`, `shopping_detail_page.dart`, `shopping_widgets.dart`, `shopping_import_page.dart`: listas/inbox, compra rápida, miembros, editor y confirmaciones |
| Integración | `lib/app/router.dart`, `recipes/presentation/recipe_detail_page.dart`, `cook_today/presentation/cook_today_page.dart`: rutas auxiliares y DTO de faltantes al detalle original |
| Localización | `lib/app/localization/app_es.arb` y Dart generado: mensajes y plural de importación; `es`/`es_ES` conservados |
| SQL | `supabase/migrations/20261013001100_shopping_client_safety.sql`, `supabase/tests/006_shopping.test.sql` |
| Tests | `test/shopping/shopping_test.dart`, `test/support/fake_shopping_repository.dart`, `test_support/shopping_local.dart`, `integration_test/shopping_native_test.dart` |
| Herramientas | `verify_shopping.ps1`, `verify_native_shopping.ps1`, `capture_shopping_android.py`, `cleanup_shopping_fixtures.py`, `audit_local_shopping_database.sql` |
| Documentos | README raíz/backend/integración, PROGRESS, decisiones, `docs/20_SHOPPING.md`, ADR-021, este informe, evidencias y capturas propias |

Baseline capturado antes de editar: **671 archivos**, HEAD
`8aefe513c201914946c05c4a1da4ed37515514fd`. Solo 12 archivos existentes cambian
dentro del alcance de integración/documentación/localización. SQL 001–010,
informes/evidencias 01–06, tests anteriores, Auth/perfil, modelos/repositorios de
recetas, algoritmo/RPC de matching, dependencias, plataforma/IDs, tema y barra
se conservan. Flutter **3.47.7**, Dart **3.13.5**; ningún pin/dependencia nuevos.

- **Migraciones/backend:** únicamente Docker local `mixtick-phase02`, PostgreSQL
  **17.11**. Reset desde cero aplica **001–011**; lint sin errores. No proyecto
  remoto/link/db push/deploy. Se mantienen **16 tablas públicas**, ahora
  **6 privadas**, **50 ingredientes / 74 alias**.

| Contrato aditivo 011 | Justificación y permisos |
|---|---|
| `private.shopping_requests` | Ledger por actor/request/tipo/hash/IDs; RLS, sin acceso cliente/API/Realtime; tombstones sin resurrección |
| `create_shopping_list_once`, `add_shopping_item_once` | Creación sin duplicados tras respuesta perdida; actor derivado de Auth, permisos/cuotas/validación histórica conservados |
| `shopping_list_snapshot` | Una sentencia invoker/RLS para cabecera/productos/miembros/invitaciones; evita datos de versiones mezcladas y N+1 de red |
| `shopping_recipe_preview` | Una sentencia invoker/RLS con versión/raciones/líneas originales/IDs/ordinales; sin pasos/foto |
| `import_recipe_checked` | Bloquea autoridad, comprueba acceso/versión/pares ID-ordinal y condición obligatoria; reutiliza la importación idempotente de Fase 02 |
| `shopping_invitation_inbox` | Receptor pendiente ve título de lista y username público del remitente; no productos/membresías, sigue sin acceso a lista hasta aceptar |

Los definers están en `private`, con search_path vacío, wrappers invoker y
EXECUTE mínimo. Se mantienen todas las RPC/grants/RLS históricos. Importación
no suma cantidades, convierte unidades, escala raciones ni modifica comprado.
El origen privado queda fuera de productos: sin título/autor/receta UUID/
descripción/pasos/foto. Repetir una operación confirmada devuelve sus IDs
originales y revalida permisos; no reintroduce borrados ni reinicia comprado.

- **Comandos ejecutados:** códigos finales reales; `<FLUTTER>/<DART>` son los
  SDK de `C:\Users\Sergio\develop\flutter\bin`, `<PY>` Python **3.12.14** funcional
  del runtime de Codex y `<CLI>` Supabase **2.120.0** en `.tooling/supabase/`.
  `<NET>` es el ID completo de `mixtick-local-tests` usado con adaptador loopback.
  Argumentos/horas/códigos: [calidad final](phase07/evidence/results.json),
  [backend/regresiones/Android](phase07/evidence/results-backend-and-native.json),
  [Android final](phase07/evidence/native-results.json). El JSON combinado
  conserva una ejecución anterior de compra; la salida final siguiente incluye
  las mediciones completas y la lectura por UUID actual.

| Comando/comprobación | Código | Resultado/evidencia |
|---|---:|---|
| `start_isolated_supabase.ps1` / `assert_local_isolation.ps1` | 0 | PASS: bindings/listeners 127.0.0.1; 18 probes externos sin conexión. [JSON](phase07/evidence/isolation.json) |
| `<CLI> db reset --local --network-id <NET>` mediante adaptador | 0 | PASS: 11 migraciones desde cero. [Salida](phase07/evidence/db-reset.txt) |
| `<CLI> test db --network-id <NET>` | 0 | PASS: 84 checks, 6 archivos; 72 anteriores +12 nuevos. [Salida](phase07/evidence/sql-tests.txt) |
| `<CLI> db lint --local --level warning --network-id <NET>` | 0 | PASS: results vacío. [Salida](phase07/evidence/db-lint.txt) |
| `<PY> scripts/test_database_api.py --cli <CLI> --evidence-dir .../regression-db` | 0 | PASS: 20 escenarios A/B/C anteriores. [Salida](phase07/evidence/api-regression.txt) |
| `<FLUTTER> test test_support/recipes_local.dart --dart-define-from-file=... --reporter expanded` | 0 | PASS: 16, incluido 1 híbrido histórico. [Salida](phase07/evidence/recipes-real-client.txt) |
| Mismo comando para `community_local.dart` | 0 | PASS: 30, incluidos 2 híbridos históricos. [Salida](phase07/evidence/community-real-client.txt) |
| Mismo comando para `matching_local.dart` | 0 | PASS: 23, incluidos 2 híbridos históricos. [Salida](phase07/evidence/matching-real-client.txt) |
| Mismo comando para `shopping_local.dart` | 0 | PASS: 16, incluidos 2 híbridos identificados. WebSockets A/B reales, C/anon negativos y medición de 200 productos. [Final](phase07/evidence/shopping-real-client-final.txt) |
| `cleanup_*_fixtures.py`, incluidos p7/nativos | 0 | PASS: solo cuentas/objetos registrados; [compra final](phase07/evidence/shopping-final-cleanup.txt), [Android](phase07/evidence/native-fixture-cleanup.txt) |
| `auth_profile_local.dart` con auto-confirmación local | 0 | PASS: 13. [Salida](phase07/evidence/auth-regression-auto-confirm.txt) |
| Misma suite con confirmación Mailpit real activada temporalmente | 0 | PASS: 13; config restaurada. [Salida](phase07/evidence/auth-regression-email-confirm.txt) |
| `verify_native_recipes.ps1 -EvidenceDirectory .../phase07/recipe-regression/evidence` | 0 | PASS: CRUD/privacidad/galería Android originales. [JSON](phase07/recipe-regression/evidence/native-results.json), [salida](phase07/recipe-regression/evidence/native-recipes.txt) |
| `verify_native_shopping.ps1` / `flutter test integration_test/shopping_native_test.dart -d emulator-5554 --no-uninstall ...` | 0 | PASS: 1 test de flujos múltiples reales, 50 s de test final. [Salida](phase07/evidence/native-shopping.txt), [capturas](phase07/evidence/native-captures.txt) |
| `<FLUTTER> gen-l10n` | 0 | PASS. [Salida](phase07/evidence/gen-l10n.txt) |
| `<FLUTTER> analyze` | 0 | PASS: sin incidencias. [Salida](phase07/evidence/flutter-analyze.txt) |
| `<FLUTTER> test --reporter expanded` | 0 | PASS: 114. [Salida](phase07/evidence/flutter-test.txt) |
| `<DART> format --output=none --set-exit-if-changed lib test test_support integration_test scripts/loopback_docker.dart` | 0 | PASS: 104 archivos, 0 cambios. [Salida](phase07/evidence/format-check.txt) |
| `<PY> scripts/check_identifiers.py --strict` | 0 | PASS: mixtick, namespace/applicationId/MainActivity y 3 Runner iOS. [Salida](phase07/evidence/identifiers.txt) |
| `<FLUTTER> build apk --debug` | 0 | PASS: APK estándar de main. [Salida](phase07/evidence/android-debug-build.txt), [identidad](phase07/evidence/apk-identity.txt) |
| Auditoría SQL/Mailpit y parada exclusiva local/emulador | 0 | PASS: cero fixtures/correos; [BD](phase07/evidence/database-audit.json), [correo](phase07/evidence/mail-audit.json), [stack](phase07/evidence/local-stop-verification.json), [emulador](phase07/evidence/emulator-stop.txt) |
| iOS, dispositivo físico, dos Android simultáneos | — | NOT_RUN: Windows sin Xcode; no móvil físico ni segundo Android utilizados |

APK `build/app/outputs/flutter-apk/app-debug.apk`: **245.879.218 bytes**,
SHA256 **96D72E816C7253B761F300949EE6787BC22E97E1DE31A40828D932057A8054AB**.
[Hash calculado](phase07/evidence/apk-sha256.json). MixTick,
`es.sergiotech.mixtick`, MainActivity aprobada, compileSdk 36. Es debug, excluido
de Git; no firma/distribución. Se recompiló main después del APK de integración.

- **Pruebas:** 114 Flutter =99 aceptadas intactas +15 nuevas (2 dominio,
  13 widgets/estado). SQL nuevo comprueba estructura/permisos/publicación;
  pruebas de producto/seguridad usan Auth GoTrue y JWT públicos reales A/B/C.
  Los mocks solo prueban UI/estado. Dos de los 16 casos de compra son híbridos:
  consumir respuesta de commit real y provocar pérdida de transporte, y retener
  respuesta real durante cambio real de identidad. No se cuentan como RLS.
  La matriz usa L01–L48 de la autorización, no renumera la matriz histórica.

| Caso | Estado | Alcance comprobado |
|---|---|---|
| L01 crear | PASS | RPC real e interfaz Android; actor propietario de Auth |
| L02 renombrar | PASS | Persistencia real y versión obsoleta rechazada; editor UI |
| L03 múltiples listas | PASS | Propias y compartidas de B; selector real de destino |
| L04 eliminar/confirmar | PASS | Borrado real/versionado/tombstone; widget exige confirmación y prueba Cancelar |
| L05 añadir | PASS | Manual libre, creación idempotente y entrada rápida Android |
| L06 editar campos | PASS | Nombre/cantidad/unidad reales; 0,125 l en Android |
| L07 comprar/desmarcar | PASS | API ambos sentidos; toggle optimista reconciliado en widget, marcado Android |
| L08 borrar producto | PASS | API versionada, ausencia final y señal de lista vía WebSocket |
| L09 grupos | PASS | Pendientes/comprados en widgets y Android |
| L10 persistencia | PASS | Cliente nuevo inicia sesión y recupera los mismos IDs/estados del servidor |
| L11 invitar | PASS | Username registrado, actor owner; UI Android |
| L12 aceptar | PASS | Cuatro aceptaciones concurrentes reales producen una membresía; UI Android |
| L13 rechazar | PASS | Rechazo real/idempotente, no habilita aceptación posterior |
| L14 duplicados | PASS | Pending duplicada/self/usuario inexistente rechazados |
| L15 aceptación ajena | PASS | A/C intentan aceptar invitación de B por UUID conocido: denegado |
| L16 miembro escribe | PASS | B cambia producto y comprado; A consulta cambios reales |
| L17 ajenos | PASS | C/B antes de aceptar no leen/modifican; INSERT miembro directo denegado |
| L18 expulsar | PASS | JWT vigente ya no lee/escribe; Android oculta contenido en revalidación; editor denegado se cierra |
| L19 abandonar | PASS | RPC real, pierde membresía y no restaura por invitación anterior |
| L20 invitación antigua | PASS | Revocada/abandonada no crea membresía al reaceptar |
| L21 A añade/B ve | PASS | Dos WebSockets reales; Android B recibe inserción de sesión A en plazo de 5 s |
| L22 B compra/A ve | PASS | Evento WebSocket de A y lectura autorizada; dueño consulta marcado Android B |
| L23 concurrentes | PASS | Dos ediciones simultáneas: una gana, otra conflicto |
| L24 versiones | PASS | PT409 real; UI conserva borrador y bloquea guardado hasta recarga confirmada |
| L25 reconexión | PASS | Se cierra socket B, A escribe, B vuelve a suscribir y relee estado correcto |
| L26 duplicados | PASS | Mock de señales repetidas/fuera de orden agrupa una lectura; estado sin filas duplicadas |
| L27 logout | PASS | Canal real retirado al salir; widgets cierran modal/draft/canal y cambian lista |
| L28 usuarios no autorizados | PASS | C y anon intentan suscripción SDK directa y no reciben productos; cliente app ni abre canal sin snapshot permitido |
| L29 borrado/membresía | PASS | Borrado provoca UPDATE de lista recibido; revocación detectada por lectura RLS/probe y elimina agregado |
| L30 receta propia | PASS | Private de A a lista compartida; preview/confirmación Android |
| L31 pública | PASS | B importa receta pública accesible de A |
| L32 faltantes | PASS | Matching real genera DTO; solo Miso blanco/Patata obligatorios según fixture; flujo Android y stale preview sin importación |
| L33 cantidades | PASS | 1,25 ud, 2,5 g, 0,125 g y raciones 2,5 originales; Patata 0,5 kg en faltantes |
| L34 retry | PASS | UUID idéntico/reordenación, payload alterado rechazado y pérdida de respuesta híbrida sin duplicados |
| L35 comprado | PASS | Retry no destacha; producto borrado no resucita |
| L36 nombres | PASS | Catálogo conservado y texto libre Miso/Jabón; no interpretación culinaria forzada |
| L37 privada ajena | PASS | B no obtiene preview ni importa privada de A |
| L38 lista ajena | PASS | C intenta importar pública a lista conocida de A: denegado |
| L39 atomicidad | PASS | Par ID/ordinal inválido no inserta ninguna línea; versión cambiada rechazada |
| L40 origen privado | PASS | JSON de productos B sin UUID/título/metadata de receta; B no obtiene original privado |
| L41 pestañas | PASS | Foundation y Android conservan exactamente cuatro |
| L42 recetas | PASS | 16 regresiones reales y galería/CRUD/privacidad Android anteriores sin editar sus tests |
| L43 Comunidad | PASS | 30 regresiones reales y widgets aceptados/guardadas |
| L44 matching | PASS | 23 regresiones y widgets aceptados, ambos modos/RLS; 010 intacta |
| L45 cuentas | PASS | A/B/C reales, respuesta retenida descartada al cambiar cuenta y widgets con salida |
| L46 Android | PASS | Pixel_10a Android 17/API 37, repositorios reales |
| L47 clientes independientes | PASS con límite | A/B host tienen WebSockets independientes; complementado por Android y sesión A externa; dos Android simultáneos NOT_RUN |
| L48 carga/vacío/red | PASS | Widgets, errores tipados, draft/UUID conservados, initial retry y recuperación; transporte híbrido identificado |

- **Seguridad:** RLS del servidor se mantiene como autoridad, también si se
  omite toda la UI. Evidencias reales: suites API/recetas/Comunidad/matching/
  compra y Android enlazadas; [auditoría de patrones](phase07/evidence/secret-audit.json).

| Requisitos | Verificación |
|---|---|
| S01–S03, S07, S16 | Lectura/escritura directa por UUID, pendientes/C denegados, B autorizado tras aceptación; grants impiden suplantar membresía |
| S04–S05, S12 | Owner gestiona, B no invita/revoca/renombra/borra; A/C no aceptan invitación ajena; actor de Auth y columnas de identidad no editables |
| S06, S09–S10 | JWT anterior pierde lectura/escritura tras revocación; logout retira canal; cambio de cuenta descarta respuesta; bloqueo simétrico impide invitar |
| S08 | WebSockets reales de C/anon sin eventos protegidos; sin publicación DELETE que eluda RLS |
| S11, S13–S14 | Importación no autoriza receta, hash ligado al payload, IDs/versiones actuales, atomicidad y conflicto real |
| S15 | Solo configuración pública/JWT de usuarios en clientes; sin claves administrativas embebidas ni publicadas |

Teardown privilegiado es exclusivamente host **local**: valida emails/UUID
registrados por cada suite y path/owner de sus objetos; usa Storage API para
retirar fixtures antes de borrar sus cuentas. No se usa para demostrar permisos
ni se añade a Flutter. No equivale al worker de producción.

**Realtime:** publicación existente solo INSERT/UPDATE de listas/productos.
Eventos agrupados como señales; snapshot autorizado, no payload aplicado
directamente. Se espera `system status=ok` de replicación, separado del join
Phoenix. DELETE de ítem y membresías tocan versión de lista. El expulsado ya
no recibe ese UPDATE: probe cada **15 s** visible, regreso/foreground/manual
y reconexión revalidan. Editor/bandeja revalidan cada **30 s** visible. Denegación
oculta datos y cierra canal/editor. No se promete revocación instantánea de
copias descargadas. Retry de lectura inicial reconstruye estado/canal.

- **Capturas Android:** reales, 1080×2424, Pixel_10a Android 17/API 37; inspección
  visual de las tres finales. Usuarios/productos/receta son fixtures controladas,
  nunca datos demo permanentes del seed/app. El título del appbar largo se
  abrevia con el comportamiento normal de Flutter; acción completa en el cuerpo.

| Vista | Captura |
|---|---|
| Preview de receta privada, raciones/destino/checkboxes | [Importación](phase07/previews/shopping-selection.png) |
| Lista compartida clara y productos reales | [Claro](phase07/previews/shopping-light.png) |
| Lista compartida oscura | [Oscuro](phase07/previews/shopping-dark.png) |
| Galería/editor/detalle previo, sin sobrescribir histórico | [Regresión Android](phase07/recipe-regression/previews/) |

- **Rendimiento:** una muestra autenticada local de **200 productos** registra
  snapshot/DTO **26 ms**, añadir **4 ms**, toggle **6 ms**, importar **3 líneas
  8 ms**. [Salida final](phase07/evidence/shopping-real-client-final.txt).
  No es distribución estadística, FPS móvil ni benchmark remoto. El primer
  recorrido midió 9 ms de snapshot; se conserva en su salida anterior. Listas
  usan cursor UUID/páginas de 200; productos se leen en un snapshot y se renderizan
  con ListView.builder. A este volumen no se necesitó paginar productos; mayor
  volumen requiere medición antes de decidir. Canal único por detalle visible,
  debounce 200 ms, sin N+1 de red. Señales A/B y Android efectivamente observadas;
  no se inventa una latencia de producción.

Benchmark de Fase 06 **pendiente de optimización en Fase 08 autorizada**:
Exact **1,911 s**, Near **3,138 s**, siguiente **3,637 s** con 6.000 recetas.
No se alteró 010 ni se repitió este benchmark como una mejora de matching.

- **Problemas encontrados y soluciones:** FAIL reales conservados.

| Incidencia | Corrección/evidencia |
|---|---|
| Rutas de lectura supuestas no existían / patch con operaciones duplicadas | Localización de rutas reales y patch corregido; fallos de herramienta sin modificar SQL histórico ni atribuirlos a la app |
| Primer análisis: 28 avisos; después avisos menores | Braces, resultado refresh y null assertion corregidos, sin silenciar reglas. [Inicial](phase07/evidence/analyze-initial.txt), [review](phase07/evidence/analyze-review-initial.txt); final limpio |
| Join WebSocket anterior a replicación operativa | Primer test timeout preservado. [FAIL](phase07/evidence/shopping-client-initial.txt). Ahora readiness de system y relectura; suites reales finales PASS |
| Timers Riverpod tras perder último listener | Cierre inmediato en onCancel/onDispose; reconstrucción al volver. [Widget inicial](phase07/evidence/shopping-widgets-initial.txt) |
| Spinner detrás de modal impedía settle | Vista cubierta sin canal/spinner activo, regreso con datos frescos. [Intermedio](phase07/evidence/shopping-widgets-next.txt); widgets finales PASS |
| Revisión de permisos/editor y recarga inicial | Editor denegado cierra/borra campos; revalida visible. Recarga reconstruye initial failure. [15 tests específicos](phase07/evidence/shopping-review-tests.txt) |
| Android pulsó CTA mientras cambiaba posición | Hit-test fatal detectó offset obsoleto; helper vuelve a asegurar visibilidad y comprueba hit target. [FAIL preservado](phase07/evidence/native-shopping-review-initial.txt), [JSON](phase07/evidence/native-results-review-initial.json); Android final PASS |
| Gradle/JDK/XML SDK | Avisos heredados de acceso nativo y versión XML; builds/tests terminan. No se afirma entorno sin advertencias ni se aceptan nuevas licencias |

- **Limitaciones y riesgos:** conexión necesaria; no offline completo ni
  persistencia de borradores fuera de su sesión/pantalla. HTTP en curso no
  revierte una transacción aceptada; los UUID/versiones/relectura resuelven
  ambigüedad. Revocación visible depende de revalidación; no de publicar eventos
  inseguros. Invitación pendiente solo revela su título/remitente autorizado,
  no productos. Cambiar receta requiere revisar de nuevo, especialmente faltantes.
  No hay suma/escalado/conversión. Dos Android simultáneos no probados: se usa
  la alternativa de clientes host independientes más Android expresamente
  permitida. iOS/físico, remoto/CDN, worker, eliminación de cuenta, moderación
  operativa y optimización de matching conservados como gates de lanzamiento.

**Limpieza:** auditoría final: 0 Auth/perfiles/recetas/componentes/social/listas/
productos/miembros/invitaciones/fotos/avatares/jobs/ledgers/quotas y correos.
Solo catálogo 50/74 y esquema 11/16/6 permanecen. Stack local y emulador
propio verificado apagados; modo noche restaurado. No cambios a Docker global,
firewall, otros proyectos, datos de app ajenos o backend remoto.

- **Documentación actualizada:** README raíz/backend/integración, PROGRESS,
  decisiones, `docs/20_SHOPPING.md`, ADR-021, este informe, evidencia/inventario/
  auditorías/capturas de Fase 07. Informes anteriores intactos.
- **Decisiones nuevas/ADR:** [ADR-021](../adr/021_SHOPPING.md),
  [contrato de compra/integración/sincronización](../20_SHOPPING.md).
- **Pendientes para siguiente fase:** revisión del propietario. Únicamente
  con autorización de Fase 08, auditoría/calidad y optimización medida del
  matching; conservar gates de lanzamiento descritos. No se inicia esa fase.
- **¿Autorizada siguiente fase?:** **NO**. Se detiene. Sin stage/commit/push,
  despliegue, Supabase remoto ni tiendas. HEAD permanece
  `8aefe513c201914946c05c4a1da4ed37515514fd`; cambios de Fase 07 locales para revisión.

## Autorización posterior de GitHub

El 2026-10-14, después del cierre de Fase 07 descrito arriba, el propietario
solicitó «Realiza push». Autoriza crear el commit y subir este estado a
`sergineko/MixTick`, rama `main`, con código, migración, pruebas y evidencias.
Las afirmaciones anteriores sobre HEAD y ausencia de commit/push corresponden
al cierre previo a esta autorización. Se excluyen los archivos locales ignorados.
No se autoriza Fase 08, despliegue ni modificación de Supabase remoto.

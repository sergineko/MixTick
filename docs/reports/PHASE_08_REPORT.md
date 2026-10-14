# Informe final FASE 08

- **Objetivo:** auditar y preparar técnicamente MixTick para una futura distribución, exclusivamente en local, conservando los cuatro módulos, contratos, identificadores y trabajo aceptado de Fases 01–07.
- **Resultado:** **PASS para LOCAL READY. RELEASE READY: NOT_VERIFIED.** Persisten bloqueantes de infraestructura remota, plataformas y distribución. No se ha publicado ni desplegado.
- **Fecha:** 2026-10-14, Europe/Madrid.
- **Base revisada:** `main`, HEAD `2e126f04112b93e2005b6c4b414ae965e9d3dd9f`, workspace limpio antes de editar; baseline de 788 archivos. El mismo HEAD al cerrar, sin stage/commit/push.
- **Autorización:** exclusivamente Fase 08, según el texto proporcionado por el propietario. Las autorizaciones Git de fases anteriores no se reutilizan para esta fase.

## 1. Resumen ejecutivo y objetivos

Se optimizó la autorización RLS del matching manteniendo intacta su función de
ranking. Se implementaron y verificaron el worker real de borrado físico, la
eliminación de cuenta desde la app y operaciones mínimas de moderación del
servidor. Se preservaron arquitectura modular, cuatro destinos y dependencias.

| Objetivo | Estado | Resultado verificable |
|---|---|---|
| Arquitectura y alcance | PASS | UI/estado/repositorios/modelos por feature; Auth/perfil/eliminación transversales; cuatro módulos |
| Identificadores | PASS | `mixtick`, org `es.sergiotech`, applicationId/namespace/bundle `es.sergiotech.mixtick`; verificación estricta y APK |
| Matching seguro y rápido | PASS | 30 muestras/modo+2 warmups; p95 final 126–143 ms frente a 1832–2001 ms; hashes idénticos |
| Worker físico | PASS | F01–F12, leases/reintentos/barreras, caída real Storage y archivo físico observado |
| Eliminación de cuenta | PASS | D01–D12 y D13 concurrente; PostgreSQL/Storage/Auth; UI y sesión cifrada Android |
| Moderación técnica | PASS | Operador real, listado redactado, acciones/estado/auditoría, consola y rechazo de metadata falsa |
| Auditoría seguridad | PASS | 25 áreas locales, UUID conocidos sin permisos, RLS y 108 SQL y suites reales A/B/C |
| Realtime | PASS | Sockets independientes, reconexión, negativos, revoke/block, item/list delete; controles tardíos identificados |
| UX y accesibilidad local | PASS | Cuatro módulos Android claro/oscuro; widgets320/200 y checks del nuevo flujo |
| Rendimiento local | PASS | SQL, HTTP repetido, imagen isolate, Profile arranque/memoria; límites separados |
| Regresiones y Android | PASS | Suites históricas intactas,121Flutter,108SQL, siete procesos/test nativos, APKdebug y release unsigned |
| iOS, remoto y tiendas | NOT_RUN | Windows sin Xcode; sin autorización de infraestructura/publicación/firma real |
| Preparación de distribución | NOT_VERIFIED | Matriz y procedimientos preparados; faltan requisitos reales de lanzamiento |

PASS se limita a los escenarios y evidencias enlazados. No equivale a pentest,
certificación legal/accesibilidad, prueba en dos móviles físicos ni configuración
de producción comprobada.

## 2. Cambios de código y arquitectura

No se reestructuraron arbitrariamente los cuatro módulos ni se añadieron despensa,
inventario, planificación, IA, mensajería, pagos u otras funciones de negocio.
La consulta de ingredientes sigue efímera y por presencia, sin cantidades de casa.

| Rutas reales | Cambio |
|---|---|
| `lib/features/profile/domain/account_deletion_repository.dart` | Contrato y fallos tipados de eliminación |
| `lib/features/profile/data/supabase_account_deletion_repository.dart` | Reconciliación por request propio, Edge autenticada, comprobación de UID/aceptación |
| `lib/features/profile/presentation/account_deletion_page.dart` | Consecuencias, listas, contraseña/consentimiento/ELIMINAR, busy/reintento/logout, protección A→B |
| `lib/features/profile/presentation/profile_page.dart`, `lib/app/router.dart` | Entrada desde Mi perfil y ruta transversal `/account/delete` bajo SessionScope |
| `lib/features/profile/data/supabase_profile_repository.dart` | UID antes/después de operaciones |
| `lib/features/profile/presentation/profile_providers.dart` | Concilia avatar ante respuesta perdida; no borra imagen ya referenciada |
| `lib/app/localization/app_es.arb` y dos archivos generados | Cadenas españolas localizables del nuevo flujo |
| `lib/core/config/app_config.dart` | Release rechaza configuración local/IP/flags de desarrollo; elegibilidad de configuración pública solo sintáctica |
| `android/app/build.gradle.kts` | Release no reutiliza firma debug; validación unsigned |
| `supabase/functions/_shared/server.ts` | Cliente servidor limitado, borrado Storage/Auth, errores fijos, body limitado y autenticación worker |
| `supabase/functions/cleanup-storage/index.ts` | Lote físico + cuentas + mantenimiento; secreto servidor dedicado |
| `supabase/functions/delete-account/index.ts` | Identidad viva/contraseña propia, retirada duradera, revocación y recuperación |
| `supabase/config.toml` | Configuración por función; JWT conservado en delete-account |
| `test/release/` | Cinco widgets de cuenta, conciliación avatar y guard de build pública; siete pruebas nuevas |
| `test_support/release_e2e_local.dart` | E2E 23pasos, lista eliminada y mediciones HTTP/CPU reales |
| `integration_test/release_native_test.dart` | UIAndroid, foto/worker/Auth y limpieza de sesión nativa |
| `supabase/tests/007_release_audit.test.sql` | 24 casos nuevos; incluye purga real de trazas a30d sin ocultar deadletters pendientes |
| `scripts/` nuevos de release | Benchmark/comparación, operaciones, consola, wrappers nativos, captura, auditoría y teardown acotado |

Los adaptadores nativos nuevos cambian destinos de evidencia/configuración
ignorada y helpers de captura. Las aserciones originales de integración permanecen
intactas. La regresión API usa un wrapper de teardown que desvincula sus imágenes
mediante RPC versionado antes del DELETE del propietario: no altera sus20casos.

Inventario exacto de archivos nuevos/modificados y hashes históricos:
[workspace-audit](phase08/evidence/workspace-audit.json). Las545 entradas
históricas protegidas de código de prueba, migraciones y evidencias no cambiaron.
`pubspec.yaml`/lock y migraciones001–011 conservan sus bytes. No se fijaron nuevas
versiones de paquetes.

## 3. Migraciones/backend

Ejecutadas exclusivamente mediante reset de Supabase local desde cero, en orden:

| Nueva migración | Estado | Contenido |
|---|---|---|
| `20261014001200_matching_rls_sets.sql` | PASS | Sets de permisos por sentencia y semijoin de relaciones bajo RLS |
| `20261014001300_storage_worker.sql` | PASS | Gracia24h, claim/lease/fence, rutas/owners, retries/deadletter, guard de imágenes referenciadas |
| `20261014001400_account_deletion.sql` | PASS | Retirada/cascadas, cuenta activa, locks de uploads, Auth posterior y retención |
| `20261014001500_moderation_operations.sql` | PASS | Operadores privados, preview público mínimo, restricciones/acciones/auditoría y mantenimiento |

Resultado final:15 migraciones,16 tablas públicas y11privadas, todas con RLS;
ningún definer público, ningún definer propio con search_path inseguro, ningún
permiso ordinario de ejecución de los siete RPC administrativos inspeccionados.
Dos buckets privados y publicación Realtime solo de listas/items.
[Auditoría real](phase08/evidence/database-audit-final.jsonl),
[reset](phase08/evidence/db-reset.txt), [lint](phase08/evidence/db-lint.txt).

El reset aplicó la versión final de las15migraciones. Después se añadieron solo
dos pruebas de retención y se repitió la suite SQL completa:108PASS; se conserva
la ejecución anterior de 106. No se modificó una migración después del reset final.
Edge se sirvió localmente con runtime1.77.4/Deno2.1.4; ningún despliegue remoto.

## 4. Comparación de rendimiento

Mismo benchmark6000recetas/18000líneas/6000pasos, authenticated B, RLS on,
dos warmups y30muestras por modo; nueve filas cada vez, rollback y mismos hashes.

| Modo | Antes mediana/p95 ms | Final mediana/p95 ms | Reducción mediana |
|---|---:|---:|---:|
| exact | 1793,397 /1831,877 | 123,6365 /131,979 | 93,106 % |
| near | 1969,7035 /2000,719 | 138,940 /143,092 | 92,946 % |
| next | 1819,411 /1861,981 | 121,0265 /125,869 | 93,348 % |

Objetivo de ingeniería SQL<500 ms/p95<1s: PASS local. Se analizaron planes antes
de elegir la corrección. Buffers del plan raíz pasan de175–195mil hits a41–56mil
con todas las guardas finales; pico de memoria de nodo reportado3625KiB, sin
atribuirlo a RAM total. Matching010 no cambia de algoritmo ni se hace privilegiado.

En HTTP real del host,20 muestras/operación, la compra 200 da mediana 23,7755 ms y
p95 25,129 ms; la foto1024×768 en isolate,55,0305/58,076 ms. Los demás módulos,
requests/bytes, calentamientos, planes y limitaciones están en
[rendimiento](phase08/PERFORMANCE.md). No son tiempos percibidos de UI ni garantías
de producción. Se repitió el feed con una publicación real al detectar que la
primera medición contenía un feed vacío; ambas mediciones se conservan.

Flutter Profile compiló y arrancó en el emulador. Veinte reinicios de proceso,
un warmup excluido, cache del SO caliente: Activity TotalTime mediana 1364,5 ms,
p95 1414ms. Una muestra PSS119641KiB (116,84 MiB), app estándar sin configuración
de backend. No mide carga de datos, FPS de compra 200 ni dispositivos físicos.
[Profile](phase08/evidence/android-profile-attempt.txt),
[métricas](phase08/evidence/android-profile-metrics.json).

## 5. Comandos ejecutados y pruebas

Entorno instalado usado: Flutter3.47.7/Dart3.13.5, Python3.12.14,
CLI2.120.0/Docker29.8.1, PostgreSQL17.11, Pixel_10a Android17/API 37.
Se usan ejecutables absolutos configurados en los runners; no se atribuye una
prueba al alias de Python de Windows Store. Cada grupo tiene salida conservada.

| Comando/runner ejecutado | Salida/código | Estado |
|---|---|---|
| `scripts/verify_release.ps1` | analyze0 sin incidencias,121tests0, formato0, strictIDs0 | PASS |
| `scripts/verify_release.ps1 -BackendChecks -BackendOnly -ResetLocal` | reset/lint/API/suites/Auth por modo0 | PASS |
| CLI `test db --network-id …` final | 7 archivos,108 tests, exit0 | PASS |
| `scripts/release_api_regression.py` | 20 casos originales intactos, exit0 | PASS |
| `flutter test test_support/auth_profile_local.dart …` | 13por modo; auto y confirmación Mailpit, ambos0 | PASS |
| `flutter test test_support/recipes_local.dart …` | 16, uno híbrido; exit0 | PASS |
| `flutter test test_support/community_local.dart …` | 30, dos híbridos; exit0 | PASS |
| `flutter test test_support/matching_local.dart …` | 23, dos híbridos; exit0 | PASS |
| `flutter test test_support/shopping_local.dart …` | 16, dos híbridos; sockets reales; exit0 | PASS |
| `scripts/test_release_operations.py --label operator-cli-final` | 34 casos reales, exit0 y teardown0 | PASS |
| `flutter test test_support/release_e2e_local.dart …` | 3 tests,23 pasos+Realtime+rendimiento; exit0/cleanup0 | PASS |
| Benchmark original y `benchmark_release_matching.py` por etapa | EXPLAIN/muestras/rollback, exit0 | PASS |
| `scripts/compare_release_benchmarks.py` | Entorno/filas/hashes idénticos, exit0 | PASS |
| `verify_release_native_auth.ps1` | Dos procesos Android, exit0 y callback real | PASS |
| `verify_native_recipes.ps1 -EvidenceDirectory …phase08…` | Un test, galería real, exit0 | PASS |
| Wrappers release native community/matching/shopping | Un test por módulo, todos0 | PASS |
| `verify_release_native_account.ps1` final | Un test UI+worker+Auth+secure storage, exit0 | PASS |
| `flutter run --profile -d emulator-5554 --no-resident` | APK Profile construido/instalado/iniciado, exit0 | PASS |
| `measure_release_android.py --mode profile` | 20 muestras+memoria real, exit0 | PASS |
| `flutter build apk --release --target-platform android-arm64` | APK21,1 MB, exit0, sin firma real | PASS |
| `flutter build apk --debug` | APK estándar `lib/main.dart`, exit0 | PASS |
| `apksigner verify --verbose` debug | v2 válido, exit0 | PASS |
| `apksigner verify --verbose` release | exit1 por firma ausente, comprobación unsigned esperada | PASS |
| `check_identifiers.py --strict` | applicationId/namespace/iOS, exit0 | PASS |
| Auditorías DB/workspace/fixtures/puertos | Sin datos de prueba ni cambios históricos/secret-pattern hits | PASS |
| iOS build/ejecución y dispositivos físicos | Sin Xcode/hardware compatible | NOT_RUN |
| Infraestructura remota/tiendas/firma real | Sin autorización ni ejecución | NOT_RUN |

Detalles y argumentos completos: [regresiones](phase08/evidence/backend-regression-results.json),
[calidad final](phase08/evidence/results.json),
[salida final](phase08/evidence/quality-final-all.txt),
[SQL 108](phase08/evidence/sql-tests.txt),
[operaciones34](phase08/evidence/operations-operator-cli-final/results.json),
[reproducción](phase08/REPRODUCE.md).

## 6. Estado del worker y eliminación de datos

F01–F12: PASS. Se distingue encolado de archivo físico, se respeta gracia, se
conserva la referencia activa, se bloquea reenlace tras claim, se recuperan leases
caducadas y claims stale, y una caída real Storage agota cinco intentos/produce
deadletter. Tras corregir la caída, recuperación operativa acotada preserva fence
y elimina el archivo. Bucket/ruta/owner manipulado no produce borrado cruzado.

D01–D12 y D13: PASS en la combinación indicada de backend/UIAndroid. La cuenta
propia retira perfil/recetas/social/listas propias/membresías/invitaciones y
auxiliares, encola sus archivos y borra Auth después de Storage. D10 detiene Auth
real después de la aceptación y demuestra recuperación. D13 sube a la vez que se
elimina la cuenta sin reanimarla ni dejar orphan. Cuenta, receta, foto y lista B
ajenas sobreviven. D12 nativo verifica logout y ausencia de sesión cifrada.

Aceptar no significa haber terminado físicamente. `202` es trabajo duradero;
JWT antiguos siguen siendo firmas válidas hasta expirar pero no pasan las guardas
de cuenta activa. La UI advierte explícitamente el borrado de listas propias
compartidas y conserva las listas ajenas. Las copias ya exportadas no se recuperan.

Retención: trazas completadas30d, hash de UID seudonimizado, rutas de jobs hasta
purga, sin acceso cliente. Se probó realmente la purga vencida de trazas de
Storage/cuenta/moderación con fixtures SQL en rollback. Deadletters pendientes
continúan visibles; son incidencias de borrado incompleto, nunca eliminación
completa. Responsables/alertas/resolución y política de backups/CDN remotos siguen
pendientes. [Contrato y recuperación](../21_RELEASE_OPERATIONS.md).

## 7. Moderación, seguridad, Realtime y UX

O01–O07: PASS. Usuario normal no administra ni aunque falsifique metadata.
Operador asignado en tabla privada revisa/cierra/oculta/restaura/restringe/retira,
con estado esperado y auditoría. Preview privado omitido, sin correo ni identidad
del denunciante. La consola real usa JWT de operador y clave pública; no hay
quinto módulo ni clave servidor en Flutter. Tener estas herramientas no acredita
equipo humano de moderación, contacto público ni proceso de revisión.

Los25puntos de seguridad y riesgos residuales están en
[auditoría](phase08/SECURITY_AUDIT.md). A/B/C reales intentaron UUID conocidos,
relaciones privadas, guardados, Storage, invitaciones, bloqueo y listas. La
optimización no deshabilita RLS. Auditoría SQL final: cero RPC administrativos
ejecutables por anon/authenticated y cero definers con search_path inseguro.

Realtime real complementado por controles híbridos explícitos: servidor revoca
desde commit; UI ya cargada se oculta tras revalidación. Borrado de lista completa
con probe visible:14.349 ms, un canal y cinco lecturas. Duplicados/fuera de orden y
respuestas tardías se inyectan en harness controlado; no se inventa un comportamiento
del servidor. Infraestructura remota NOT_VERIFIED.

Auditoría visual de cuatro módulos y cuenta, capturas Android nuevas, widgets
claro/oscuro320/200, teclado, validación, vacíos/errores/reintento, atrás/scroll,
áreas táctiles/etiquetas/contraste nuevos:
[matriz visual/E2E/Realtime](phase08/VISUAL_E2E_AUDIT.md).
TalkBack/VoiceOver manual, certificación y pruebas físicas: NOT_RUN.

## 8. Problemas encontrados y correcciones

| Incidencia conservada | Estado inicial | Corrección y comprobación posterior |
|---|---|---|
| Analyze: dos bloques sin llaves; luego lints del nuevo E2E | FAIL | Bloques y anotación de logging de tests; analyze final0 |
| Widgets lazy/click fuera de pantalla y checkbox largo200 % | FAIL | Scroll al hit target; separar aviso y etiqueta sin quitar consecuencias;121PASS |
| Contraste medido durante transición y handle de semántica tardío | FAIL | Esperar animación, `onError` explícito y dispose en finally; tres guidelines pasan |
| Ruta física supuesta `/var/lib/storage` | FAIL | Inspección del backend real `/mnt`; F01–F12 comprueban archivos reales |
| Regex de avatar en015 omitía grupo UUID | FAIL | Regex completo, regresión SQL propia/ajena y34operacionesPASS |
| Teardown API frente a protección de foto activa | FAIL | Wrapper desvincula sus fixtures con RPC versionado;20aserciones originalesPASS |
| Nuevo fixture nativo sin PKCE storage | FAIL | Preparación con flujo implícito, como fixtures nativos anteriores; app sigue PKCE seguro |
| PNG de fixture nativo rechazado por procesador | FAIL | PNG generado válido; flujo UI/foto/worker/AuthPASS; fallo inválido conservado |
| Primer benchmark de feed vacío | NOT_VERIFIED como carga de feed | Publicación y aserción no vacío;20 muestras repetidas; ambas salidas conservadas |
| Formato pendiente tras ampliar fixture de rendimiento | FAIL | Formato final112archivos, exit0; sin cambiar pruebas históricas |
| Docker no iniciado al reanudar | NOT_RUN en ese intento | Iniciar Docker local, verificar loopback; suites posterioresPASS |
| Parse de fecha en apagado idempotente | FAIL | Tratar DateTime deserializado; backend/emulador propios finalmente apagados |
| Advertencias JDK/SDK y fuente Cupertino en release | NOT_VERIFIED para riesgo futuro | Builds0; no glifos faltantes observados Android; revisar recursos/plataformas antes de distribuir |

Historial inicial de widgets/analyze/operaciones,106SQL, contraste y fixture
nativo permanece en `phase08/evidence/` y subcarpetas `account-native/…-evidence`.
No se cambiaron aserciones antiguas para obtener PASS ni se borraron sus fallos.
El fallo de revisión automática por límite de uso no ejecutó su acción; al
reanudar se comprobó el entorno y se continuó dentro del mismo alcance local.

La revisión automática rechazó retirar la protección DELETE de fotos todavía
referenciadas por el riesgo de referencias rotas. Esa retirada no se ejecutó.
Se mantuvo la protección y se adaptó únicamente el teardown de fixtures; la
alternativa segura pasó. No queda pendiente aprobar ese debilitamiento.

## 9. Android/iOS y preparación de distribución

Android debug, Profile y release unsigned: PASS de compilación local. Identidad
del binario `es.sergiotech.mixtick`, nombre MixTick, versión0.1.0+1, minSDK24,
target/compile36. APK release se pidió para targetarm64; las bibliotecas de plugins
pueden declarar otros ABI en badging. Hashes SHA256, manifest y firma en
[evidencias](phase08/evidence/android-artifact-hashes.json). Los APK quedan en
`build/app/outputs/flutter-apk/`, ignorados; no se subieron a Git/tiendas.

Release no tiene networkSecurityConfig de desarrollo ni backup; permisos de red
y permiso interno del receiver del paquete, sin acceso general a fotos/archivos.
El picker del sistema fue probado. Callback exacto del paquete y validación app.
Modo release rechaza HTTP/IP/localflag; no se le inyectó un endpoint público ni
se afirmó conexión externa. El APK sin configuración presenta estado pendiente.

El verificador de release devuelve1 por firma ausente (esperado), mientras debug
verifica v2 con exit0. Firma real/Play/AppStore: NOT_RUN. Iconos provisionales,
icono adaptativo y marca legal final: NOT_VERIFIED. No se compraron servicios.
iOS: identificadores/fuentes inspeccionados, compilación/ejecución NOT_RUN por
Windows; revisar ATS local, assets, firma y dispositivo con Xcode.

## 10. Pendientes remotos y bloqueantes

[Matriz completa](phase08/LAUNCH_MATRIX.md): proyecto/región/roles, migraciones,
RLS/RPC reales, SMTP/confirmación/recuperación/allowlist, Storage/CDN/cache,
Realtime, despliegue/programación/alertas del worker, ciclo de borrado y retención
de backups, moderadores/soporte, métricas, cuotas/costes, Androidrelease firmado,
iOS/Xcode/dispositivos, marca/iconos, privacidad/DataSafety y recurso web funcional
de eliminación exigido por Play. Todos siguen NOT_RUN o NOT_VERIFIED remotamente.
No se marca un servicio remoto PASS por semejanza con el stack local.

## 11. Documentación, decisiones y cierre

- **Documentación actualizada:** PROGRESS y README; nuevo contrato21 de operaciones; este informe; matrices de seguridad, UX/E2E/Realtime, rendimiento, lanzamiento y reproducción; evidencias y auditorías finales.
- **Decisiones nuevas/ADR:** [ADR022](../adr/022_RELEASE_AUDIT.md): RLS por conjuntos, barrera de imágenes, retirada recuperable, política de listas, retención/moderación y límites de distribución.
- **Pendientes para una fase posterior:** exclusivamente los requisitos de lanzamiento o cambios que el propietario revise y autorice. No iniciar fases ni modificar servicios externos automáticamente.
- **¿Autorizada siguiente fase?:** NO. Detener para revisión del propietario.

Auditoría final:0 cuentas/perfiles/recetas/relaciones/listas/productos/invitaciones/
ledgers/reportes/bloqueos/seguimientos/objetos/jobs/operadores/actuaciones de prueba;
catálogo 50 y74alias conservados.0archivos físicos Storage y0correos tras teardown
acotado. Backend, funciones y emulador propios detenidos;0contenedores del proyecto
y0listeners en sus puertos. Docker global permanece disponible.
[Datos](phase08/evidence/all-fixtures-audit-final.json),
[correo](phase08/evidence/mailpit-cleanup-final.json),
[apagado](phase08/evidence/local-stop-final.json).

**LOCAL READY: PASS**, dentro del entorno y cobertura descritos.
**RELEASE READY: NOT_VERIFIED**, con los bloqueantes enumerados.
Fase 08 terminada y detenida para revisión; sin commit, push, despliegue o publicación.
